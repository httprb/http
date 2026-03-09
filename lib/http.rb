# frozen_string_literal: true

require "http/errors"
require "http/timeout/null"
require "http/timeout/per_operation"
require "http/timeout/global"
require "http/chainable"
require "http/session"
require "http/client"
require "http/connection"
require "http/options"
require "http/feature"
require "http/request"
require "http/request/writer"
require "http/response"
require "http/response/body"
require "http/response/parser"

# HTTP should be easy
module HTTP
  extend Chainable

  class << self
    # Set default headers and return a chainable session
    #
    # @example
    #   HTTP[:accept => "text/html"].get("https://example.com")
    #
    # @param headers [Hash] headers to set
    #
    # @return [HTTP::Session]
    #
    # @api public
    alias [] headers
  end
end
