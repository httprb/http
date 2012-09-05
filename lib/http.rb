require 'uri'
require 'certified'
require 'http/parser'
require 'http/version'

require 'http/chainable'
require 'http/client'
require 'http/mime_type'
require 'http/options'
require 'http/request'
require 'http/request_stream'
require 'http/response'
require 'http/response_parser'
require 'http/uri_backport' if RUBY_VERSION < "1.9.0"

# HTTP should be easy
module Http
  extend Chainable

  # The method given was not understood
  class UnsupportedMethodError < ArgumentError; end

  # Valid HTTP methods
  METHODS = [:get, :head, :post, :put, :delete, :trace, :options, :connect, :patch]

  # Matches HTTP header names when in "Canonical-Http-Format"
  CANONICAL_HEADER = /^[A-Z][a-z]*(-[A-Z][a-z]*)*$/

  # CRLF is the universal HTTP delimiter
  CRLF = "\r\n"

  class << self
    # Http[:accept => 'text/html'].get(...)
    alias_method :[], :with_headers

    # Transform to canonical HTTP header capitalization
    def canonicalize_header(header)
      header.to_s.split(/[\-_]/).map(&:capitalize).join('-')
    end
  end
end
