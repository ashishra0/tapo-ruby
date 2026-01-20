# frozen_string_literal: true

require_relative 'tapo/version'
require_relative 'tapo/errors'
require_relative 'tapo/klap_cipher'
require_relative 'tapo/discovery'
require_relative 'tapo/protocol'
require_relative 'tapo/client'

# TP-Link Tapo Ruby Client
#
# A Ruby library for controlling TP-Link Tapo smart devices.
# Supports device discovery, authentication, and control operations.
#
# @example Basic usage
#   client = Tapo::Client.new('192.168.1.100', 'user@example.com', 'password')
#   client.authenticate!
#   client.on
#   puts "Power usage: #{client.power_usage}W"
#
# @example Discovery
#   devices = Tapo::Discovery.discover
#   devices.each do |ip|
#     puts "Found device at #{ip}"
#   end
module Tapo
end
