# frozen_string_literal: true

require "http/base64"
require "http/chainable/helpers"
require "http/headers"

module HTTP
  # HTTP verb methods and client configuration DSL
  module Chainable
    include HTTP::Base64

    # Request a get sans response body
    #
    # @example
    #   HTTP.head("http://example.com")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def head(uri, options = {})
      request :head, uri, options
    end

    # Get a resource
    #
    # @example
    #   HTTP.get("http://example.com")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource
    #
    # @example
    #   HTTP.post("http://example.com", body: "data")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def post(uri, options = {})
      request :post, uri, options
    end

    # Put to a resource
    #
    # @example
    #   HTTP.put("http://example.com", body: "data")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def put(uri, options = {})
      request :put, uri, options
    end

    # Delete a resource
    #
    # @example
    #   HTTP.delete("http://example.com/resource")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def delete(uri, options = {})
      request :delete, uri, options
    end

    # Echo the request back to the client
    #
    # @example
    #   HTTP.trace("http://example.com")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def trace(uri, options = {})
      request :trace, uri, options
    end

    # Return the methods supported on the given URI
    #
    # @example
    #   HTTP.options("http://example.com")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def options(uri, options = {})
      request :options, uri, options
    end

    # Convert to a transparent TCP/IP tunnel
    #
    # @example
    #   HTTP.connect("http://example.com")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def connect(uri, options = {})
      request :connect, uri, options
    end

    # Apply partial modifications to a resource
    #
    # @example
    #   HTTP.patch("http://example.com/resource", body: "data")
    #
    # @param [String, URI] uri URI to request
    # @param [Hash] options request options
    # @return [HTTP::Response]
    # @api public
    def patch(uri, options = {})
      request :patch, uri, options
    end

    # Make an HTTP request with the given verb
    #
    # @example
    #   HTTP.request(:get, "http://example.com")
    #
    # @param (see Client#request)
    # @return [HTTP::Response]
    # @api public
    def request(verb, uri, opts = {})
      branch(default_options).request(verb, uri, opts)
    end

    # Prepare an HTTP request with the given verb
    #
    # @example
    #   HTTP.build_request(:get, "http://example.com")
    #
    # @param (see Client#build_request)
    # @return [HTTP::Request]
    # @api public
    def build_request(verb, uri, opts = {})
      branch(default_options).build_request(verb, uri, opts)
    end

    # Set timeout on the request
    #
    # @example
    #   HTTP.timeout(10).get("http://example.com")
    #
    # @overload timeout(options = {})
    #   Adds per operation timeouts to the request
    #   @param [Hash] options
    #   @option options [Float] :read Read timeout
    #   @option options [Float] :write Write timeout
    #   @option options [Float] :connect Connect timeout
    # @overload timeout(global_timeout)
    #   Adds a global timeout to the full request
    #   @param [Numeric] global_timeout
    # @return [HTTP::Client]
    # @api public
    def timeout(options)
      klass, options = case options
                       when Numeric then [HTTP::Timeout::Global, { global: options }]
                       when Hash    then [HTTP::Timeout::PerOperation, options.dup]
                       when :null   then [HTTP::Timeout::Null, {}]
                       else raise ArgumentError,
                                  "Use `.timeout(global_timeout_in_seconds)` " \
                                  "or `.timeout(connect: x, write: y, read: z)`."
                       end

      normalize_timeout_keys!(options)

      branch default_options.merge(
        timeout_class:   klass,
        timeout_options: options
      )
    end

    # Open a persistent connection to a host
    #
    # @example
    #   HTTP.persistent("http://example.com").get("/")
    #
    # @overload persistent(host, timeout: 5)
    #   Flags as persistent
    #   @param  [String] host
    #   @option [Integer] timeout Keep alive timeout
    #   @raise  [Request::Error] if Host is invalid
    #   @return [HTTP::Client] Persistent client
    # @overload persistent(host, timeout: 5, &block)
    #   Executes given block with persistent client and automatically closes
    #   connection at the end of execution.
    #
    #   @example
    #
    #       def keys(users)
    #         HTTP.persistent("https://github.com") do |http|
    #           users.map { |u| http.get("/#{u}.keys").to_s }
    #         end
    #       end
    #
    #       # same as
    #
    #       def keys(users)
    #         http = HTTP.persistent "https://github.com"
    #         users.map { |u| http.get("/#{u}.keys").to_s }
    #       ensure
    #         http.close if http
    #       end
    #
    #
    #   @yieldparam [HTTP::Client] client Persistent client
    #   @return [Object] result of last expression in the block
    # @return [HTTP::Client, Object]
    # @api public
    def persistent(host, timeout: 5)
      p_client = branch default_options.merge(keep_alive_timeout: timeout).with_persistent(host)
      return p_client unless block_given?

      yield p_client
    ensure
      p_client&.close
    end

    # Make a request through an HTTP proxy
    #
    # @example
    #   HTTP.via("proxy.example.com", 8080).get("http://example.com")
    #
    # @param [Array] proxy
    # @raise [Request::Error] if HTTP proxy is invalid
    # @return [HTTP::Client]
    # @api public
    def via(*proxy)
      proxy_hash = build_proxy_hash(proxy)

      raise(RequestError, "invalid HTTP proxy: #{proxy_hash}") unless (2..5).cover?(proxy_hash.keys.size)

      branch default_options.with_proxy(proxy_hash)
    end
    alias through via

    # Make client follow redirects
    #
    # @example
    #   HTTP.follow.get("http://example.com")
    #
    # @param [Hash] options redirect options
    # @return [HTTP::Client]
    # @see Redirector#initialize
    # @api public
    def follow(options = {})
      branch default_options.with_follow options
    end

    # Make a request with the given headers
    #
    # @example
    #   HTTP.headers("Accept" => "text/plain").get("http://example.com")
    #
    # @param [Hash] headers request headers
    # @return [HTTP::Client]
    # @api public
    def headers(headers)
      branch default_options.with_headers(headers)
    end

    # Make a request with the given cookies
    #
    # @example
    #   HTTP.cookies(session: "abc123").get("http://example.com")
    #
    # @param [Hash] cookies cookies to set
    # @return [HTTP::Client]
    # @api public
    def cookies(cookies)
      branch default_options.with_cookies(cookies)
    end

    # Force a specific encoding for response body
    #
    # @example
    #   HTTP.encoding("UTF-8").get("http://example.com")
    #
    # @param [String, Encoding] encoding encoding to use
    # @return [HTTP::Client]
    # @api public
    def encoding(encoding)
      branch default_options.with_encoding(encoding)
    end

    # Accept the given MIME type(s)
    #
    # @example
    #   HTTP.accept("application/json").get("http://example.com")
    #
    # @param [String, Symbol] type MIME type to accept
    # @return [HTTP::Client]
    # @api public
    def accept(type)
      headers Headers::ACCEPT => MimeType.normalize(type)
    end

    # Make a request with the given Authorization header
    #
    # @example
    #   HTTP.auth("Bearer token123").get("http://example.com")
    #
    # @param [#to_s] value Authorization header value
    # @return [HTTP::Client]
    # @api public
    def auth(value)
      headers Headers::AUTHORIZATION => value.to_s
    end

    # Make a request with the given Basic authorization header
    #
    # @example
    #   HTTP.basic_auth(user: "user", pass: "pass").get("http://example.com")
    #
    # @see http://tools.ietf.org/html/rfc2617
    # @param [#fetch] opts
    # @option opts [#to_s] :user
    # @option opts [#to_s] :pass
    # @return [HTTP::Client]
    # @api public
    def basic_auth(opts)
      user  = opts.fetch(:user)
      pass  = opts.fetch(:pass)
      creds = "#{user}:#{pass}"

      auth("Basic #{encode64(creds)}")
    end

    # Get options for HTTP
    #
    # @example
    #   HTTP.default_options
    #
    # @return [HTTP::Options]
    # @api public
    def default_options
      @default_options ||= HTTP::Options.new
    end

    # Set options for HTTP
    #
    # @example
    #   HTTP.default_options = { response: :object }
    #
    # @param [Hash] opts options to set
    # @return [HTTP::Options]
    # @api public
    def default_options=(opts)
      @default_options = HTTP::Options.new(opts)
    end

    # Set TCP_NODELAY on the socket
    #
    # @example
    #   HTTP.nodelay.get("http://example.com")
    #
    # @return [HTTP::Client]
    # @api public
    def nodelay
      branch default_options.with_nodelay(true)
    end

    # Enable one or more features
    #
    # @example
    #   HTTP.use(:auto_inflate).get("http://example.com")
    #
    # @param [Array<Symbol, Hash>] features features to enable
    # @return [HTTP::Client]
    # @api public
    def use(*features)
      branch default_options.with_features(features)
    end

    # Return a retriable client that retries on failure
    #
    # @example Usage
    #
    #   # Retry max 5 times with randomly growing delay between retries
    #   HTTP.retriable.get(url)
    #
    #   # Retry max 3 times with randomly growing delay between retries
    #   HTTP.retriable(tries: 3).get(url)
    #
    #   # Retry max 3 times with 1 sec delay between retries
    #   HTTP.retriable(tries: 3, delay: proc { 1 }).get(url)
    #
    #   # Retry max 3 times with geometrically progressed delay between retries
    #   HTTP.retriable(tries: 3, delay: proc { |i| 1 + i*i }).get(url)
    #
    # @param (see Performer#initialize)
    # @return [HTTP::Retriable::Client]
    # @api public
    def retriable(**options)
      Retriable::Client.new(Retriable::Performer.new(options), default_options)
    end

    private

    # Create a new client with the given options
    #
    # @param [HTTP::Options] options options for the client
    # @return [HTTP::Client]
    # @api private
    def branch(options)
      HTTP::Client.new(options)
    end
  end
end
