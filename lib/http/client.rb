# frozen_string_literal: true

require "forwardable"

require "http/client/request_builder"
require "http/form_data"
require "http/retriable/performer"
require "http/options"
require "http/feature"
require "http/headers"
require "http/connection"
require "http/redirector"
require "http/uri"

module HTTP
  # Clients make requests and receive responses
  class Client
    extend Forwardable
    include Chainable
    include RequestBuilder

    # Pattern matching HTTP or HTTPS URI schemes
    HTTP_OR_HTTPS_RE = %r{^https?://}i

    # Initialize a new HTTP Client
    #
    # @example
    #   client = HTTP::Client.new(headers: {"Accept" => "application/json"})
    #
    # @param default_options [HTTP::Options, nil] existing options instance
    # @param options [Hash] keyword options (see HTTP::Options#initialize)
    # @return [HTTP::Client] a new client instance
    # @api public
    def initialize(default_options = nil, **)
      @default_options = HTTP::Options.new(default_options, **)
      @connection = nil
      @state = :clean
    end

    # Make an HTTP request
    #
    # @example
    #   client.request(:get, "https://example.com")
    #
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @param opts [Hash] request options
    # @return [HTTP::Response] the response
    # @api public
    def request(verb, uri, opts = {})
      opts = @default_options.merge(opts)
      req = build_request(verb, uri, opts)
      res = perform(req, opts)
      return res unless opts.follow

      Redirector.new(opts.follow).perform(req, res) do |request|
        perform(wrap_request(request, opts), opts)
      end
    end

    # Prepare an HTTP request
    #
    # @example
    #   client.build_request(:get, "https://example.com")
    #
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @param opts [Hash] request options
    # @return [HTTP::Request] the built request object
    # @api public
    def build_request(verb, uri, opts = {})
      opts    = @default_options.merge(opts)
      uri     = make_request_uri(uri, opts)
      headers = make_request_headers(opts)
      body    = make_request_body(opts, headers)

      req = HTTP::Request.new({
        verb:           verb,
        uri:            uri,
        uri_normalizer: opts.feature(:normalize_uri)&.normalizer,
        proxy:          opts.proxy,
        headers:        headers,
        body:           body
      })

      wrap_request(req, opts)
    end

    # @!method persistent?
    #   Indicate whether the client has persistent connections
    #
    #   @example
    #     client.persistent?
    #
    #   @see Options#persistent?
    #   @return [Boolean] whenever client is persistent
    #   @api public
    def_delegator :default_options, :persistent?

    # Perform a single (no follow) HTTP request
    #
    # @example
    #   client.perform(request, options)
    #
    # @param req [HTTP::Request] the request to perform
    # @param options [HTTP::Options] request options
    # @return [HTTP::Response] the response
    # @api public
    def perform(req, options)
      if options.retriable
        perform_with_retry(req, options)
      else
        perform_once(req, options)
      end
    end

    # Close the connection and reset state
    #
    # @example
    #   client.close
    #
    # @return [void]
    # @api public
    def close
      @connection&.close
      @connection = nil
      @state = :clean
    end

    private

    # Execute a single HTTP request without retry logic
    #
    # @param req [HTTP::Request] the request to perform
    # @param options [HTTP::Options] request options
    # @return [HTTP::Response] the response
    # @api private
    def perform_once(req, options)
      verify_connection!(req.uri)

      @state = :dirty

      send_request(req, options)
      res = build_wrapped_response(req, options)

      @connection.finish_response if req.verb == :head
      @state = :clean

      res
    rescue
      close
      raise
    end

    # Execute a request with retry logic
    #
    # @param req [HTTP::Request] the request to perform
    # @param options [HTTP::Options] request options
    # @return [HTTP::Response] the response
    # @api private
    def perform_with_retry(req, options)
      Retriable::Performer.new(options.retriable).perform(self, req) do
        perform_once(req, options)
      end
    end

    # Send request over the connection, handling proxy and errors
    # @return [void]
    # @api private
    def send_request(req, options)
      @connection ||= HTTP::Connection.new(req, options)

      unless @connection.failed_proxy_connect?
        @connection.send_request(req)
        @connection.read_headers!
      end
    rescue Error => e
      options.features.each_value do |feature|
        feature.on_error(req, e)
      end
      raise
    end

    # Build response and apply feature wrapping
    # @return [HTTP::Response] the wrapped response
    # @api private
    def build_wrapped_response(req, options)
      res = build_response(req, options)

      options.features.values.reverse.inject(res) do |response, feature|
        feature.wrap_response(response)
      end
    end

    # Wrap request through feature middleware
    # @return [HTTP::Request] the wrapped request
    # @api private
    def wrap_request(req, opts)
      opts.features.inject(req) do |request, (_name, feature)|
        feature.wrap_request(request)
      end
    end

    # Build a response from the current connection
    # @return [HTTP::Response] the built response
    # @api private
    def build_response(req, options)
      Response.new(
        status:        @connection.status_code,
        version:       @connection.http_version,
        headers:       @connection.headers,
        proxy_headers: @connection.proxy_response_headers,
        connection:    @connection,
        encoding:      options.encoding,
        request:       req
      )
    end

    # Verify our request isn't going to be made against another URI
    #
    # @return [void]
    # @api private
    def verify_connection!(uri)
      if default_options.persistent? && uri.origin != default_options.persistent
        raise StateError, "Persistence is enabled for #{default_options.persistent}, but we got #{uri.origin}"
      end

      # We re-create the connection object because we want to let prior requests
      # lazily load the body as long as possible, and this mimics prior functionality.
      return close if @connection && (!@connection.keep_alive? || @connection.expired?)

      # If we get into a bad state (eg, Timeout.timeout ensure being killed)
      # close the connection to prevent potential for mixed responses.
      close if @state == :dirty
    end
  end
end
