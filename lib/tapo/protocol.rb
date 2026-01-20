# frozen_string_literal: true

require 'net/http'
require 'json'

module Tapo
  module Protocol

    # @param device_ip [String] IP address of the device
    # @return [Symbol, nil] :klap, :passthrough, or nil if not a Tapo device
    def self.detect(device_ip)
      uri = URI("http://#{device_ip}/")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = { method: 'get_device_info' }.to_json

      response = http.request(request)

      return :klap if response.code == '401'

      begin
        json_response = JSON.parse(response.body)
        error_code = json_response['error_code']

        # Error code 1003 = method not found - device doesn't support Passthrough Protocol
        return :klap if error_code == 1003

        # Other error codes indicate Passthrough protocol
        :passthrough
      rescue JSON::ParserError
        # HTML/XML response - not a Tapo device
        nil
      end
    rescue StandardError => e
      warn "Protocol detection error for #{device_ip}: #{e.message}" if ENV['DEBUG']
      nil
    end
  end
end
