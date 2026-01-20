# frozen_string_literal: true

require 'net/http'
require 'json'
require 'base64'
require 'digest'

module Tapo
  class Client
    attr_reader :device_ip

    # @param device_ip [String] IP address of the Tapo device
    # @param username [String] Tapo account email address
    # @param password [String] Tapo account password
    def initialize(device_ip, username, password)
      @device_ip = device_ip
      @username = username
      @password = password
      @session = nil
    end

    # @return [Boolean] true if authentication successful
    # @raise [AuthenticationError] if authentication fails
    def authenticate!
      protocol = Protocol.detect(@device_ip)

      case protocol
      when :klap
        authenticate_klap!
      when :passthrough
        raise UnsupportedProtocolError, 'Passthrough protocol not yet implemented'
      else
        raise AuthenticationError, 'Unable to detect device protocol'
      end

      true
    end

    # @return [Boolean] true if authenticated
    def authenticated?
      !@session.nil?
    end

    # @return [Hash] Response from device
    def on
      set_device_info(device_on: true)
    end

    # @return [Hash] Response from device
    def off
      set_device_info(device_on: false)
    end

    # @return [Hash] Device information including name, state, model, etc.
    def device_info
      response = request(method: 'get_device_info')
      result = response['result']

      # Decode base64-encoded fields
      result['nickname'] = Base64.decode64(result['nickname']) if result['nickname']
      result['ssid'] = Base64.decode64(result['ssid']) if result['ssid']

      result
    end

    # @return [Hash] Energy usage data with proper units
    def energy_usage
      response = request(method: 'get_energy_usage')
      result = response['result']

      # Convert power: milliwatts -> watts
      if result['current_power']
        result['power_w'] = (result['current_power'] / 1000.0).round(3)
        result['power_kw'] = (result['current_power'] / 1_000_000.0).round(3)
      end

      # Convert voltage: millivolts -> volts
      if result['voltage_mv']
        result['voltage_v'] = (result['voltage_mv'] / 1000.0).round(2)
      end

      # Convert current: milliamps -> amps
      if result['current_ma']
        result['current_a'] = (result['current_ma'] / 1000.0).round(3)
      end

      # Energy consumption with units
      if result['today_energy']
        result['today_energy_wh'] = result['today_energy']
        result['today_energy_kwh'] = (result['today_energy'] / 1000.0).round(3)
      end

      if result['month_energy']
        result['month_energy_wh'] = result['month_energy']
        result['month_energy_kwh'] = (result['month_energy'] / 1000.0).round(3)
      end

      # Runtime with units
      result['today_runtime_min'] = result['today_runtime'] if result['today_runtime']
      result['month_runtime_min'] = result['month_runtime'] if result['month_runtime']

      if result['today_runtime']
        result['today_runtime_hours'] = (result['today_runtime'] / 60.0).round(2)
      end

      if result['month_runtime']
        result['month_runtime_hours'] = (result['month_runtime'] / 60.0).round(2)
      end

      result
    end

    # @return [Float] Current power in watts (W)
    def power_usage
      energy = energy_usage
      energy['power_w']
    end


    # @return [Float, nil] Current voltage in volts (V)
    def voltage
      energy = energy_usage
      energy['voltage_v']
    end

    # @return [Float, nil] Current in amps (A)
    def current
      energy = energy_usage
      energy['current_a']
    end

    # @return [Boolean] true if device is on
    def on?
      device_info['device_on']
    end

    # Check if device is off
    #
    # @return [Boolean] true if device is off
    def off?
      !on?
    end

    # @return [String] Device nickname
    def nickname
      device_info['nickname']
    end

    # @param params [Hash] Parameters to set (e.g., device_on: true)
    # @return [Hash] Response from device
    def set_device_info(params)
      request(method: 'set_device_info', params: params)
    end

    # @param request_data [Hash] Request data
    # @return [Hash] Response from device
    # @raise [SessionExpiredError] if session has expired
    # @raise [RequestError] if request fails
    def request(request_data)
      authenticate! unless authenticated?

      json_payload = request_data.to_json

      encrypted_payload, seq = @session[:cipher].encrypt(json_payload)

      http = @session[:http]
      request = Net::HTTP::Post.new("/app/request?seq=#{seq}", 'Content-Type' => 'application/octet-stream')
      request['Cookie'] = @session[:cookie]
      request.body = encrypted_payload

      response = http.request(request)

      if response.code == '403'
        @session = nil
        raise SessionExpiredError, 'Session expired, please re-authenticate'
      end

      raise RequestError, "Request failed with status #{response.code}" if response.code != '200'

      decrypted_response = @session[:cipher].decrypt(response.body, seq)
      result = JSON.parse(decrypted_response)

      if result['error_code'] != 0
        raise RequestError, "Device returned error code: #{result['error_code']}"
      end

      result
    rescue SessionExpiredError
      authenticate!
      retry
    end

    private

    def authenticate_klap!
      base_url = "http://#{@device_ip}/app"
      uri = URI(base_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      username_hash = Digest::SHA1.digest(@username)
      password_hash = Digest::SHA1.digest(@password)
      auth_hash = Digest::SHA256.digest(username_hash + password_hash)

      local_seed = OpenSSL::Random.random_bytes(16)

      handshake1_req = Net::HTTP::Post.new('/app/handshake1', 'Content-Type' => 'application/octet-stream')
      handshake1_req.body = local_seed

      handshake1_res = http.request(handshake1_req)
      raise AuthenticationError, "Handshake1 failed: #{handshake1_res.code}" if handshake1_res.code != '200'

      cookie_header = handshake1_res['set-cookie']
      cookie = nil
      if cookie_header && cookie_header =~ /TP_SESSIONID=([^;]+)/
        cookie = "TP_SESSIONID=#{Regexp.last_match(1)}"
      end

      response_body = handshake1_res.body
      raise AuthenticationError, 'Response too small' if response_body.bytesize < 48

      response_body = response_body[0, 48] if response_body.bytesize > 48

      remote_seed = response_body[0, 16]
      server_hash = response_body[16, 32]

      local_hash = Digest::SHA256.digest(local_seed + remote_seed + auth_hash)
      if local_hash != server_hash
        raise AuthenticationError, 'Authentication failed - wrong credentials'
      end

      client_hash = Digest::SHA256.digest(remote_seed + local_seed + auth_hash)

      handshake2_req = Net::HTTP::Post.new('/app/handshake2', 'Content-Type' => 'application/octet-stream')
      handshake2_req['Cookie'] = cookie if cookie
      handshake2_req.body = client_hash

      handshake2_res = http.request(handshake2_req)
      raise AuthenticationError, "Handshake2 failed: #{handshake2_res.code}" if handshake2_res.code != '200'

      cipher = KlapCipher.new(local_seed, remote_seed, auth_hash)

      @session = {
        cookie: cookie,
        cipher: cipher,
        device_ip: @device_ip,
        http: http
      }
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise AuthenticationError, "Device not responding: #{e.message}"
    end
  end
end
