# frozen_string_literal: true

module HTTP
  class Request
    # Decides whether a request can be sent again on a new connection
    module Idempotency
      # Idempotent methods (RFC 9110, Section 9.2.2)
      IDEMPOTENT_METHODS = %i[get head options trace put delete].freeze

      # Headers that mark any request as idempotent (draft-ietf-httpapi-idempotency-key-header)
      IDEMPOTENCY_KEY_HEADERS = %w[Idempotency-Key X-Idempotency-Key].freeze

      # Whether the request can be sent again after a connection failure
      #
      # True when the method is idempotent or an idempotency key header is
      # present, and the body is nil or a String, so it can be written again.
      #
      # @example
      #   request.replayable? # => true
      #
      # @return [Boolean]
      # @api public
      def replayable?
        source = body.source
        return false unless source.nil? || source.is_a?(String)

        IDEMPOTENT_METHODS.include?(verb) || IDEMPOTENCY_KEY_HEADERS.any? { |name| headers.include?(name) }
      end
    end
  end
end
