# frozen_string_literal: true
module HTTP
  class Logger
    attr_reader :logger, :print_options

    # @param [#info] logger
    # @param [Hash] options
    def initialize(logger, options = {})
      @logger = logger

      with = options.fetch(:with, [])
      @print_options = {
        :skip_headers => !with.include?(:headers),
        :skip_body    => !with.include?(:body),
        :separator    => "\n"
      }
    end

    # Logs HTTP request and response.
    #
    # @param [HTTP::Request] request
    # @param [HTTP::Response] response
    def log(request, response)
      return unless logger

      log_info(request)
      log_info(response)
    end

    private

    def log_info(http)
      logger.info(http.pretty_print(print_options))
    end
  end
end
