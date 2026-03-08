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
        logger.debug { "#{stringify_headers(response.headers)}\n\n#{response.body}" }

        response
      end

      private

      # Convert headers to a string representation
      # @return [String]
      # @api private
      def stringify_headers(headers)
        headers.map { |name, value| "#{name}: #{value}" }.join("\n")
      end
    end
  end
end
