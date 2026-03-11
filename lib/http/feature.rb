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

    # Callback invoked before each request attempt
    #
    # Unlike {#wrap_request}, which is called once when the request is built,
    # this hook is called before every attempt, including retries. Use it for
    # per-attempt side effects like starting instrumentation spans.
    #
    # @example
    #   feature.on_request(request)
    #
    # @param _request [HTTP::Request]
    # @return [nil]
    # @api public
    def on_request(_request); end

    # Wraps the HTTP exchange for a single request attempt
    #
    # Called once per attempt (including retries), wrapping the send and
    # receive cycle. The block performs the I/O and returns the response.
    # Override this to add behavior that must span the entire exchange,
    # such as instrumentation spans or circuit breakers.
    #
    # @example Timing a request
    #   def around_request(request)
    #     start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    #     yield(request).tap { log_duration(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) }
    #   end
    #
    # @param request [HTTP::Request]
    # @yield [HTTP::Request] the request to perform
    # @yieldreturn [HTTP::Response]
    # @return [HTTP::Response] must return the response from yield
    # @api public
    def around_request(request)
      yield request
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
require "http/features/digest_auth"
require "http/features/instrumentation"
require "http/features/logging"
require "http/features/normalize_uri"
require "http/features/raise_error"
