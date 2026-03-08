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

        raise StatusError, response
      end

      HTTP::Options.register_feature(:raise_error, self)
    end
  end
end
