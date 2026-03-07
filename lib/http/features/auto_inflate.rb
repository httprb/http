# frozen_string_literal: true

require "set"

module HTTP
  module Features
    class AutoInflate < Feature
      SUPPORTED_ENCODING = Set.new(%w[deflate gzip x-gzip]).freeze
      private_constant :SUPPORTED_ENCODING

      # Wraps a response with an auto-inflating body
      #
      # @example
      #   feature.wrap_response(response)
      #
      # @param response [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def wrap_response(response)
        return response unless supported_encoding?(response)

        Response.new(inflated_response_options(response))
      end

      # Returns an inflating body stream for a connection
      #
      # @example
      #   feature.stream_for(connection)
      #
      # @param connection [HTTP::Connection]
      # @return [HTTP::Response::Body]
      # @api public
      def stream_for(connection)
        Response::Body.new(Response::Inflater.new(connection))
      end

      private

      # Build options hash for an inflated response
      # @api private
      def inflated_response_options(response)
        {
          status:        response.status,
          version:       response.version,
          headers:       response.headers,
          proxy_headers: response.proxy_headers,
          connection:    response.connection,
          body:          stream_for(response.connection),
          request:       response.request
        }
      end

      # Check if the response encoding is supported
      # @api private
      def supported_encoding?(response)
        content_encoding = response.headers.get(Headers::CONTENT_ENCODING).first
        content_encoding && SUPPORTED_ENCODING.include?(content_encoding)
      end

      HTTP::Options.register_feature(:auto_inflate, self)
    end
  end
end
