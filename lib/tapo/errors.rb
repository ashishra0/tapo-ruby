# frozen_string_literal: true

module Tapo
  class Error < StandardError; end

  class DiscoveryError < Error; end

  class AuthenticationError < Error; end

  class RequestError < Error; end

  class SessionExpiredError < Error; end

  class UnsupportedProtocolError < Error; end
end
