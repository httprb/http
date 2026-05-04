# frozen_string_literal: true

module HTTP
  module Features
    # Raises an error for non-successful HTTP responses
    class RaiseError < Feature
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

        error_class =
          case response.code
          when 400 then BadRequestError
          when 401 then UnauthorizedError
          when 402 then PaymentRequiredError
          when 403 then ForbiddenError
          when 404 then NotFoundError
          when 405 then MethodNotAllowedError
          when 406 then NotAcceptableError
          when 407 then ProxyAuthenticationRequiredError
          when 408 then RequestTimeoutError
          when 409 then ConflictError
          when 410 then GoneError
          when 411 then LengthRequiredError
          when 412 then PreconditionFailedError
          when 413 then ContentTooLargeError
          when 414 then UriTooLongError
          when 415 then UnsupportedMediaTypeError
          when 416 then RangeNotSatisfiableError
          when 417 then ExpectationFailedError
          when 418 then ImATeapotError
          when 421 then MisdirectedRequestError
          when 422 then UnprocessableContentError
          when 423 then LockedError
          when 424 then FailedDependencyError
          when 425 then TooEarlyError
          when 426 then UpgradeRequiredError
          when 428 then PreconditionRequiredError
          when 429 then TooManyRequestsError
          when 431 then RequestHeaderFieldsTooLargeError
          when 451 then UnavailableForLegalReasonsError
          when 400...500 then ClientError # Generic client error if the 4xx code is unmapped.
          when 500 then InternalServerError
          when 501 then NotImplementedError
          when 502 then BadGatewayError
          when 503 then ServiceUnavailableError
          when 504 then GatewayTimeoutError
          when 505 then HttpVersionNotSupportedError
          when 506 then VariantAlsoNegotiatesError
          when 507 then InsufficientStorageError
          when 508 then LoopDetectedError
          when 510 then NotExtendedError
          when 511 then NetworkAuthenticationRequiredError
          when 500...600 then ServerError # Generic server error if the 5xx code is unmapped.
          else StatusError
          end

        raise error_class, response
      end

      HTTP::Options.register_feature(:raise_error, self)
    end
  end
end
