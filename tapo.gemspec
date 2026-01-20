# frozen_string_literal: true

require_relative 'lib/tapo/version'

Gem::Specification.new do |spec|
  spec.name          = 'tapo'
  spec.version       = Tapo::VERSION
  spec.authors       = ['Ashish Rao']
  spec.email         = ['ashishrao2598@gmail.com']

  spec.summary       = 'Ruby client for TP-Link Tapo smart devices'
  spec.description   = 'Control TP-Link Tapo smart plugs (P100, P110) with Ruby. Supports device discovery, authentication via KLAP protocol, and energy monitoring.'
  spec.homepage      = 'https://github.com/ashishrao7/tapo-ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ashishrao7/tapo-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/ashishrao7/tapo-ruby/blob/main/CHANGELOG.md'

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']

  # No runtime dependencies - uses only Ruby standard library!
end
