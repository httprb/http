# frozen_string_literal: true

module HTTP
  # Generic error
  class Error < StandardError; end

  # Generic Connection error
  class ConnectionError < Error; end

  # Types of Connection errors
  class ResponseHeaderError < ConnectionError; end
  # Error raised when reading from a socket fails
  class SocketReadError < ConnectionError; end
  # Error raised when writing to a socket fails
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

  # Client errors 4xx
  class ClientError < StatusError; end
  class BadRequestError < ClientError; end
  class UnauthorizedError < ClientError; end
  class PaymentRequiredError < ClientError; end
  class ForbiddenError < ClientError; end
  class NotFoundError < ClientError; end
  class MethodNotAllowedError < ClientError; end
  class NotAcceptableError < ClientError; end
  class ProxyAuthenticationRequiredError < ClientError; end
  class RequestTimeoutError < ClientError; end
  class ConflictError < ClientError; end
  class GoneError < ClientError; end
  class LengthRequiredError < ClientError; end
  class PreconditionFailedError < ClientError; end
  class ContentTooLargeError < ClientError; end
  class UriTooLongError < ClientError; end
  class UnsupportedMediaTypeError < ClientError; end
  class RangeNotSatisfiableError < ClientError; end
  class ExpectationFailedError < ClientError; end
  class ImATeapotError < ClientError; end
  class MisdirectedRequestError < ClientError; end
  class UnprocessableContentError < ClientError; end
  class LockedError < ClientError; end
  class FailedDependencyError < ClientError; end
  class TooEarlyError < ClientError; end
  class UpgradeRequiredError < ClientError; end
  class PreconditionRequiredError < ClientError; end
  class TooManyRequestsError < ClientError; end
  class RequestHeaderFieldsTooLargeError < ClientError; end
  class UnavailableForLegalReasonsError < ClientError; end

  # Server errors 5xx
  class ServerError < StatusError; end
  class InternalServerError < ServerError; end
  class NotImplementedError < ServerError; end
  class BadGatewayError < ServerError; end
  class ServiceUnavailableError < ServerError; end
  class GatewayTimeoutError < ServerError; end
  class HttpVersionNotSupportedError < ServerError; end
  class VariantAlsoNegotiatesError < ServerError; end
  class InsufficientStorageError < ServerError; end
  class LoopDetectedError < ServerError; end
  class NotExtendedError < ServerError; end
  class NetworkAuthenticationRequiredError < ServerError; end

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
