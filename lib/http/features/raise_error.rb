# frozen_string_literal: true

module HTTP
  module Features
    # Raises an error for non-successful HTTP responses
    class RaiseError < Feature
      CODE_TO_ERROR_CLASS = {
        400 => BadRequestError,
        401 => UnauthorizedError,
        402 => PaymentRequiredError,
        403 => ForbiddenError,
        404 => NotFoundError,
        405 => MethodNotAllowedError,
        406 => NotAcceptableError,
        407 => ProxyAuthenticationRequiredError,
        408 => RequestTimeoutError,
        409 => ConflictError,
        410 => GoneError,
        411 => LengthRequiredError,
        412 => PreconditionFailedError,
        413 => ContentTooLargeError,
        414 => UriTooLongError,
        415 => UnsupportedMediaTypeError,
        416 => RangeNotSatisfiableError,
        417 => ExpectationFailedError,
        418 => ImATeapotError,
        421 => MisdirectedRequestError,
        422 => UnprocessableContentError,
        423 => LockedError,
        424 => FailedDependencyError,
        425 => TooEarlyError,
        426 => UpgradeRequiredError,
        428 => PreconditionRequiredError,
        429 => TooManyRequestsError,
        431 => RequestHeaderFieldsTooLargeError,
        451 => UnavailableForLegalReasonsError,
        500 => InternalServerError,
        501 => NotImplementedError,
        502 => BadGatewayError,
        503 => ServiceUnavailableError,
        504 => GatewayTimeoutError,
        505 => HttpVersionNotSupportedError,
        506 => VariantAlsoNegotiatesError,
        507 => InsufficientStorageError,
        508 => LoopDetectedError,
        510 => NotExtendedError,
        511 => NetworkAuthenticationRequiredError
      }.freeze

      # Initializes the RaiseError feature
      #
      # @example
      #   RaiseError.new(ignore: [404])
      #
      # @param ignore [Array<Integer>] status codes to ignore
      # @return [RaiseError]
      # @api public
      def initialize(ignore: [])
        @ignore = ignore
      end

      # Raises an error for non-successful responses
      #
      # @example
      #   feature.wrap_response(response)
      #
      # @param response [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def wrap_response(response)
        return response if response.code < 400
        return response if @ignore.include?(response.code)

        default_error_class =
          case response.code
          when 400...500 then ClientError
          when 500...600 then ServerError
          else StatusError
          end

        raise CODE_TO_ERROR_CLASS.fetch(response.code, default_error_class), response
      end

      HTTP::Options.register_feature(:raise_error, self)
    end
  end
end
