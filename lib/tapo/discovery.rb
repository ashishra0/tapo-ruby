# frozen_string_literal: true

require 'socket'
require 'timeout'
require 'openssl'
require 'json'
require 'digest/crc32'

module Tapo
  module Discovery
    DISCOVERY_PORT = 20002
    BROADCAST_ADDR = '255.255.255.255'

    # @param timeout [Integer] How long to listen for responses in seconds
    # @return [Array<String>] Array of discovered device IP addresses
    def self.discover(timeout: 5)
      socket = UDPSocket.new
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.bind('0.0.0.0', 0)

      payload = build_discovery_payload
      socket.send(payload, 0, BROADCAST_ADDR, DISCOVERY_PORT)

      listen_for_responses(socket, timeout)
    ensure
      socket&.close
    end

    # @return [String] Binary discovery packet
    def self.build_discovery_payload
      rsa_key = OpenSSL::PKey::RSA.new(1024)
      public_key_pem = rsa_key.public_key.to_pem

      json_body = {
        params: {
          rsa_key: public_key_pem
        }
      }.to_json

      version = 2
      msg_type = 0
      op_code = 1
      msg_size = json_body.bytesize
      flags = 17
      padding = 0
      device_serial = rand(0..0xFFFFFFFF)
      crc_placeholder = 0x5A6B7C8D

      header = [
        version, msg_type, op_code, msg_size, flags, padding,
        device_serial, crc_placeholder
      ].pack('CCnnCCNN')

      full_message_for_crc = header + json_body
      real_crc = Digest::CRC32.checksum(full_message_for_crc)

      header[12, 4] = [real_crc].pack('N')

      header + json_body
    end

    # @param socket [UDPSocket] The socket to listen on
    # @param timeout [Integer] How long to listen in seconds
    # @return [Array<String>] Array of discovered IP addresses
    def self.listen_for_responses(socket, timeout)
      discovered_ips = []

      begin
        Timeout.timeout(timeout) do
          loop do
            ready = IO.select([socket])
            next unless ready

            _, addr_info = socket.recvfrom_nonblock(2048)
            device_ip = addr_info[2]

            discovered_ips << device_ip unless discovered_ips.include?(device_ip)
          end
        end
      rescue Timeout::Error
        puts "Timeout reached"
      rescue IO::WaitReadable
        puts "No response received"
      end

      discovered_ips
    end

    private_class_method :build_discovery_payload, :listen_for_responses
  end
end
