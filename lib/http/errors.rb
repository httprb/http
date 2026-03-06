# frozen_string_literal: true

module HTTP
  # Generic error
  class Error < StandardError; end

  # Generic Connection error
  class ConnectionError < Error; end

  # Types of Connection errors
  class ResponseHeaderError < ConnectionError; end
  class SocketReadError < ConnectionError; end
  class SocketWriteError < ConnectionError; end

  # Generic Request error
  class RequestError < Error; end

  # Generic Response error
  class ResponseError < Error; end

  # Requested to do something when we're in the wrong state
  class StateError < ResponseError; end

  # When status code indicates an error
  class StatusError < ResponseError
    # The HTTP response that caused the error
    #
    # @example
    #   error.response
    #
    # @return [HTTP::Response]
    # @api public
    attr_reader :response

    # Create a new StatusError from a response
    #
    # @example
    #   HTTP::StatusError.new(response)
    #
    # @param [HTTP::Response] response the response with error status
    # @return [StatusError]
    # @api public
    def initialize(response)
      @response = response

      super("Unexpected status code #{response.code}")
    end
  end

  # Raised when `Response#parse` fails due to any underlying reason (unexpected
  # MIME type, or decoder fails). See `Exception#cause` for the original exception.
  class ParseError < ResponseError; end

  # Requested MimeType adapter not found.
  class UnsupportedMimeTypeError < Error; end

  # Generic Timeout error
  class TimeoutError < Error; end

  # Timeout when first establishing the connection
  class ConnectTimeoutError < TimeoutError; end

  # Header value is of unexpected format (similar to Net::HTTPHeaderSyntaxError)
  class HeaderError < Error; end
end
