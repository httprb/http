require 'http/parser'

require 'http/chainable'
require 'http/client'
require 'http/options'
require 'http/request'
require 'http/request_stream'
require 'http/response'
require 'http/response_body'
require 'http/response_parser'
require 'http/uri_backport' if RUBY_VERSION < '1.9.0'

# HTTP should be easy
module HTTP
  # Request to do something when we're in the wrong state
  class StateError < StandardError; end

  extend Chainable

  class << self
    # HTTP[:accept => 'text/html'].get(...)
    alias_method :[], :with_headers
  end
end

Http = HTTP unless defined?(Http)
