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
    # Binary bodies (IO/Enumerable request sources and binary-encoded
    # responses) are formatted using the +binary_formatter+ option instead
    # of being dumped raw. Available formatters:
    #
    # - +:stats+ (default) — logs <tt>BINARY DATA (N bytes)</tt>
    # - +:base64+ — logs <tt>BINARY DATA (N bytes)\n<base64></tt>
    # - +Proc+ — calls the proc with the raw binary string
    #
    # @example Custom binary formatter
    #    HTTP.use(logging: {logger: Logger.new(STDOUT), binary_formatter: :base64})
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
      # @example With binary formatter
      #   Logging.new(logger: Logger.new(STDOUT), binary_formatter: :base64)
      #
      # @param logger [#info, #debug] logger instance
      # @param binary_formatter [:stats, :base64, #call] how to log binary bodies
      # @return [Logging]
      # @api public
      def initialize(logger: NullLogger.new, binary_formatter: :stats)
        super()
        @logger = logger
        @binary_formatter = validate_binary_formatter!(binary_formatter)
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
        log_request_details(request)

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

      # Validate and return the binary_formatter option
      # @return [:stats, :base64, #call]
      # @raise [ArgumentError] if the formatter is not a valid option
      # @api private
      def validate_binary_formatter!(formatter)
        return formatter if formatter == :stats || formatter == :base64 || formatter.respond_to?(:call)

        raise ArgumentError,
              "binary_formatter must be :stats, :base64, or a callable " \
              "(got #{formatter.inspect})"
      end

      # Log request headers and body (when loggable)
      # @return [void]
      # @api private
      def log_request_details(request)
        headers = stringify_headers(request.headers)
        if request.body.loggable?
          source = request.body.source
          body = source.encoding == Encoding::BINARY ? format_binary(source) : source
          logger.debug { "#{headers}\n\n#{body}" }
        else
          logger.debug { headers }
        end
      end

      # Log response with body inline (for non-streaming string bodies)
      # @return [HTTP::Response]
      # @api private
      def log_response_body_inline(response)
        body    = response.body
        headers = stringify_headers(response.headers)
        if body.respond_to?(:encoding) && body.encoding == Encoding::BINARY
          logger.debug { "#{headers}\n\n#{format_binary(body)}" } # steep:ignore
        else
          logger.debug { "#{headers}\n\n#{body}" }
        end
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
        formatter = body.loggable? ? nil : method(:format_binary) # steep:ignore
        stream = BodyLogger.new(body.instance_variable_get(:@stream), logger, formatter: formatter) # steep:ignore
        Response::Body.new(stream, encoding: body.encoding)
      end

      # Format binary data according to the configured binary_formatter
      # @return [String]
      # @api private
      def format_binary(data)
        case @binary_formatter
        when :stats
          format("BINARY DATA (%d bytes)", data.bytesize)
        when :base64
          format("BINARY DATA (%d bytes)\n%s", data.bytesize, [data].pack("m0"))
        else
          @binary_formatter.call(data) # steep:ignore
        end
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
        # @param formatter [#call, nil] optional formatter for each chunk
        # @return [BodyLogger]
        # @api public
        def initialize(stream, logger, formatter: nil)
          @stream = stream
          @connection = stream.respond_to?(:connection) ? stream.connection : stream
          @logger = logger
          @formatter = formatter
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
          @logger.debug { @formatter ? @formatter.call(chunk) : chunk } # steep:ignore
          chunk
        end
      end
    end
  end
end
