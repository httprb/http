# frozen_string_literal: true

module HTTP
  # Base class for HTTP client features (middleware)
  class Feature
    # Wraps an HTTP request
    #
    # @example
    #   feature.wrap_request(request)
    #
    # @param request [HTTP::Request]
    # @return [HTTP::Request]
    # @api public
    def wrap_request(request)
      request
    end

    # Wraps an HTTP response
    #
    # @example
    #   feature.wrap_response(response)
    #
    # @param response [HTTP::Response]
    # @return [HTTP::Response]
    # @api public
    def wrap_response(response)
      response
    end

    # Callback for request errors
    #
    # @example
    #   feature.on_error(request, error)
    #
    # @param _request [HTTP::Request]
    # @param _error [Exception]
    # @return [nil]
    # @api public
    def on_error(_request, _error); end
  end
end

require "http/features/auto_inflate"
require "http/features/auto_deflate"
require "http/features/instrumentation"
require "http/features/logging"
require "http/features/normalize_uri"
require "http/features/raise_error"
