# frozen_string_literal: true

module HTTP
  module Features
    # Instrument requests and responses. Expects an
    # ActiveSupport::Notifications-compatible instrumenter. Defaults to use a
    # namespace of 'http' which may be overridden with a `:namespace` param.
    # Emits a single event like `"request.{namespace}"`, eg `"request.http"`.
    # Be sure to specify the instrumenter when enabling the feature:
    #
    #    HTTP
    #      .use(instrumentation: {instrumenter: ActiveSupport::Notifications.instrumenter})
    #      .get("https://example.com/")
    #
    # Emits two events on every request:
    #
    #  * `start_request.http` before the request is made, so you can log the reqest being started
    #  * `request.http` after the response is recieved, and contains `start`
    #    and `finish` so the duration of the request can be calculated.
    #
    class Instrumentation < Feature
      # The instrumenter instance
      #
      # @example
      #   feature.instrumenter
      #
      # @return [#instrument] the instrumenter instance
      # @api public
      attr_reader :instrumenter

      # The event name for requests
      #
      # @example
      #   feature.name # => "request.http"
      #
      # @return [String] the event name for requests
      # @api public
      attr_reader :name

      # The event name for errors
      #
      # @example
      #   feature.error_name # => "error.http"
      #
      # @return [String] the event name for errors
      # @api public
      attr_reader :error_name

      # Initializes the Instrumentation feature
      #
      # @example
      #   Instrumentation.new(instrumenter: ActiveSupport::Notifications.instrumenter)
      #
      # @param instrumenter [#instrument] instrumenter instance
      # @param namespace [String] event namespace
      # @return [Instrumentation]
      # @api public
      def initialize(instrumenter: NullInstrumenter.new, namespace: "http")
        super()
        @instrumenter = instrumenter
        @name = "request.#{namespace}"
        @error_name = "error.#{namespace}"
      end

      # Wraps a request with instrumentation events
      #
      # @example
      #   feature.wrap_request(request)
      #
      # @param request [HTTP::Request]
      # @return [HTTP::Request]
      # @api public
      def wrap_request(request)
        # Emit a separate "start" event, so a logger can print the request
        # being run without waiting for a response
        instrumenter.instrument("start_#{name}", request: request)
        instrumenter.start(name, request: request)
        request
      end

      # Wraps a response with instrumentation events
      #
      # @example
      #   feature.wrap_response(response)
      #
      # @param response [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def wrap_response(response)
        instrumenter.finish(name, response: response)
        response
      end

      # Instruments a request error
      #
      # @example
      #   feature.on_error(request, error)
      #
      # @param request [HTTP::Request]
      # @param error [Exception]
      # @return [Object]
      # @api public
      def on_error(request, error)
        instrumenter.instrument(error_name, request: request, error: error)
      end

      HTTP::Options.register_feature(:instrumentation, self)

      class NullInstrumenter
        # Instruments an event with a name and payload
        #
        # @example
        #   instrumenter.instrument("request.http", request: req)
        #
        # @param name [String]
        # @param payload [Hash]
        # @return [Object]
        # @api public
        def instrument(name, payload = {})
          start(name, payload)
          begin
            yield payload if block_given?
          ensure
            finish name, payload
          end
        end

        # Starts an instrumentation event
        #
        # @example
        #   instrumenter.start("request.http", request: req)
        #
        # @param _name [String]
        # @param _payload [Hash]
        # @return [true]
        # @api public
        def start(_name, _payload) # rubocop:disable Naming/PredicateMethod
          true
        end

        # Finishes an instrumentation event
        #
        # @example
        #   instrumenter.finish("request.http", response: resp)
        #
        # @param _name [String]
        # @param _payload [Hash]
        # @return [true]
        # @api public
        def finish(_name, _payload) # rubocop:disable Naming/PredicateMethod
          true
        end
      end
    end
  end
end
