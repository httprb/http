# frozen_string_literal: true

require "http/base64"
require "http/chainable/helpers"
require "http/chainable/verbs"
require "http/headers"

module HTTP
  # HTTP verb methods and client configuration DSL
  module Chainable
    include HTTP::Base64
    include Verbs

    # Make an HTTP request with the given verb
    #
    # @example
    #   HTTP.request(:get, "http://example.com")
    #
    # @param (see Client#request)
    # @return [HTTP::Response]
    # @api public
    def request(verb, uri, opts = {})
      make_client(default_options).request(verb, uri, opts)
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
      make_client(default_options).build_request(verb, uri, opts)
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
    #   @option options [Float] :global Global timeout (combines with per-operation)
    # @overload timeout(global_timeout)
    #   Adds a global timeout to the full request
    #   @param [Numeric] global_timeout
    # @return [HTTP::Session]
    # @api public
    def timeout(options)
      klass, options = case options
                       when Numeric then [HTTP::Timeout::Global, { global_timeout: options }]
                       when Hash    then resolve_timeout_hash(options)
                       when :null   then [HTTP::Timeout::Null, {}]
                       else raise ArgumentError,
                                  "Use `.timeout(:null)`, " \
                                  "`.timeout(global_timeout_in_seconds)` or " \
                                  "`.timeout(connect: x, write: y, read: z)`."
                       end

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
      options = default_options.merge(keep_alive_timeout: timeout).with_persistent(host)
      p_client = make_client(options)
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
    # @return [HTTP::Session]
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
    # @return [HTTP::Session]
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
    # @return [HTTP::Session]
    # @api public
    def headers(headers)
      branch default_options.with_headers(headers)
    end

    # Make a request with the given cookies
    #
    # @example
    #   HTTP.cookies(session: "abc123").get("http://example.com")
    #
    # @param [Hash, Array<HTTP::Cookie>] cookies cookies to set
    # @return [HTTP::Session]
    # @api public
    def cookies(cookies)
      value = cookies.map do |entry|
        case entry
        when HTTP::Cookie then entry.cookie_value
        else
          name, val = entry
          HTTP::Cookie.new(name.to_s, val.to_s).cookie_value
        end
      end.join("; ")

      headers(Headers::COOKIE => value)
    end

    # Force a specific encoding for response body
    #
    # @example
    #   HTTP.encoding("UTF-8").get("http://example.com")
    #
    # @param [String, Encoding] encoding encoding to use
    # @return [HTTP::Session]
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
    # @return [HTTP::Session]
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
    # @return [HTTP::Session]
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
    # @return [HTTP::Session]
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
    # @param [Hash, HTTP::Options] opts options to set
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
    # @return [HTTP::Session]
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
    # @return [HTTP::Session]
    # @api public
    def use(*features)
      branch default_options.with_features(features)
    end

    # Return a retriable session that retries on failure
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
    # @return [HTTP::Session]
    # @api public
    def retriable(**options)
      branch default_options.with_retriable(options.empty? || options)
    end

    private

    # Create a new session with the given options
    #
    # @param [HTTP::Options] options options for the session
    # @return [HTTP::Session]
    # @api private
    def branch(options)
      HTTP::Session.new(options)
    end

    # Create a new client for executing a request
    #
    # @param [HTTP::Options] options options for the client
    # @return [HTTP::Client]
    # @api private
    def make_client(options)
      HTTP::Client.new(options)
    end
  end
end
