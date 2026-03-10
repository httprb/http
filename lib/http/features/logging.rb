# frozen_string_literal: true

module HTTP
  # Namespace for HTTP client features
  module Features
    # Log requests and responses. Request verb and uri, and Response status are
    # logged at `info`, and the headers and bodies of both are logged at
    # `debug`. Be sure to specify the logger when enabling the feature:
    #
    #    HTTP.use(logging: {logger: Logger.new(STDOUT)}).get("https://example.com/")
    #
    class Logging < Feature
      HTTP::Options.register_feature(:logging, self)

      # No-op logger used as default when none is provided
      class NullLogger
        %w[fatal error warn info debug].each do |level|
          define_method(level.to_sym) do |*_args|
            nil
          end

          define_method(:"#{level}?") do
            true
          end
        end
      end

      # The logger instance
      #
      # @example
      #   feature.logger
      #
      # @return [#info, #debug] the logger instance
      # @api public
      attr_reader :logger

      # Initializes the Logging feature
      #
      # @example
      #   Logging.new(logger: Logger.new(STDOUT))
      #
      # @param logger [#info, #debug] logger instance
      # @return [Logging]
      # @api public
      def initialize(logger: NullLogger.new)
        super()
        @logger = logger
      end

      # Logs and returns the request
      #
      # @example
      #   feature.wrap_request(request)
      #
      # @param request [HTTP::Request]
      # @return [HTTP::Request]
      # @api public
      def wrap_request(request)
        logger.info { "> #{request.verb.to_s.upcase} #{request.uri}" }
        logger.debug { "#{stringify_headers(request.headers)}\n\n#{request.body.source}" }

        request
      end

      # Logs and returns the response
      #
      # @example
      #   feature.wrap_response(response)
      #
      # @param response [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def wrap_response(response)
        logger.info { "< #{response.status}" }

        return log_response_body_inline(response) unless response.body.is_a?(Response::Body)

        logger.debug { stringify_headers(response.headers) }
        return response unless logger.debug?

        Response.new(**logged_response_options(response)) # steep:ignore
      end

      private

      # Log response with body inline (for non-streaming string bodies)
      # @return [HTTP::Response]
      # @api private
      def log_response_body_inline(response)
        logger.debug { "#{stringify_headers(response.headers)}\n\n#{response.body}" }
        response
      end

      # Build options hash for a response with body logging
      # @return [Hash]
      # @api private
      def logged_response_options(response)
        {
          status:        response.status,
          version:       response.version,
          headers:       response.headers,
          proxy_headers: response.proxy_headers,
          connection:    response.connection,
          body:          logged_body(response.body),
          request:       response.request
        }
      end

      # Wrap a response body with a logging stream
      # @return [HTTP::Response::Body]
      # @api private
      def logged_body(body)
        stream = BodyLogger.new(body.instance_variable_get(:@stream), logger)
        Response::Body.new(stream, encoding: body.encoding)
      end

      # Convert headers to a string representation
      # @return [String]
      # @api private
      def stringify_headers(headers)
        headers.map { |name, value| "#{name}: #{value}" }.join("\n")
      end

      # Stream wrapper that logs each chunk as it flows through readpartial
      class BodyLogger
        # The underlying connection
        #
        # @example
        #   body_logger.connection
        #
        # @return [HTTP::Connection] the underlying connection
        # @api public
        attr_reader :connection

        # Create a new BodyLogger wrapping a stream
        #
        # @example
        #   BodyLogger.new(stream, logger)
        #
        # @param stream [#readpartial] the stream to wrap
        # @param logger [#debug] the logger instance
        # @return [BodyLogger]
        # @api public
        def initialize(stream, logger)
          @stream = stream
          @connection = stream.respond_to?(:connection) ? stream.connection : stream
          @logger = logger
        end

        # Read a chunk from the underlying stream and log it
        #
        # @example
        #   body_logger.readpartial # => "chunk"
        #
        # @return [String] the chunk read from the stream
        # @raise [EOFError] when no more data left
        # @api public
        def readpartial(*)
          chunk = @stream.readpartial(*)
          @logger.debug { chunk }
          chunk
        end
      end
    end
  end
end
