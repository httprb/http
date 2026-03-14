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
    # @example Without a block
    #   HTTP.request(:get, "http://example.com")
    #
    # @example With a block (auto-closes connection)
    #   HTTP.request(:get, "http://example.com") { |res| res.status }
    #
    # @param (see Client#request)
    # @yieldparam response [HTTP::Response] the response
    # @return [HTTP::Response, Object] the response, or block return value
    # @api public
    def request(verb, uri, **, &block)
      client   = make_client(default_options)
      response = client.request(verb, uri, **)
      return response unless block

      yield response
    ensure
      client&.close if block
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

    # Set a base URI for resolving relative request paths
    #
    # The first call must use an absolute URI that includes a scheme
    # (e.g. "https://example.com"). Once a base URI is set, subsequent chained
    # calls may use relative paths that are resolved against the existing base.
    #
    # @example
    #   HTTP.base_uri("https://example.com/api/v1").get("users")
    #
    # @example Chaining base URIs
    #   HTTP.base_uri("https://example.com").base_uri("api/v1").get("users")
    #
    # @param [String, HTTP::URI] uri the base URI (absolute with scheme when
    #   no base is set; may be relative when chaining)
    # @return [HTTP::Session]
    # @raise [HTTP::Error] if no base URI is set and the given URI has no scheme
    # @api public
    def base_uri(uri)
      branch default_options.with_base_uri(uri)
    end

    # Open a persistent connection to a host
    #
    # Returns an {HTTP::Session} that pools persistent {HTTP::Client}
    # instances by origin. This allows connection reuse within the same
    # origin and transparent cross-origin redirect handling.
    #
    # When no host is given, the origin is derived from the configured base URI.
    #
    # @example
    #   HTTP.persistent("http://example.com").get("/")
    #
    # @example Derive host from base URI
    #   HTTP.base_uri("https://example.com/api").persistent.get("users")
    #
    # @overload persistent(host = nil, timeout: 5)
    #   Flags as persistent
    #   @param  [String, nil] host connection origin (derived from base URI when nil)
    #   @option [Integer] timeout Keep alive timeout
    #   @raise  [ArgumentError] if host is nil and no base URI is set
    #   @raise  [Request::Error] if Host is invalid
    #   @return [HTTP::Session] Persistent session
    # @overload persistent(host = nil, timeout: 5, &block)
    #   Executes given block with persistent session and automatically closes
    #   all connections at the end of execution.
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
    #   @yieldparam [HTTP::Session] session Persistent session
    #   @return [Object] result of last expression in the block
    # @return [HTTP::Session, Object]
    # @api public
    def persistent(host = nil, timeout: 5)
      host ||= default_options.base_uri&.origin
      raise ArgumentError, "host is required for persistent connections" unless host

      options = default_options.merge(keep_alive_timeout: timeout).with_persistent(host)
      session = branch(options)
      return session unless block_given?

      yield session
    ensure
      session&.close if block_given?
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
    # @param [Boolean] strict (true) redirector hops policy
    # @param [Integer] max_hops (5) maximum allowed redirect hops
    # @param [#call, nil] on_redirect optional redirect callback
    # @return [HTTP::Session]
    # @see Redirector#initialize
    # @api public
    def follow(strict: nil, max_hops: nil, on_redirect: nil)
      opts = { strict: strict, max_hops: max_hops, on_redirect: on_redirect }.compact
      branch default_options.with_follow(opts)
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
    # @param [#to_s] user
    # @param [#to_s] pass
    # @return [HTTP::Session]
    # @api public
    def basic_auth(user:, pass:)
      auth("Basic #{encode64("#{user}:#{pass}")}")
    end

    # Enable HTTP Digest authentication
    #
    # Automatically handles 401 Digest challenges by computing the digest
    # response and retrying the request with proper credentials.
    #
    # @example
    #   HTTP.digest_auth(user: "admin", pass: "secret").get("http://example.com")
    #
    # @see https://datatracker.ietf.org/doc/html/rfc2617
    # @param [#to_s] user
    # @param [#to_s] pass
    # @return [HTTP::Session]
    # @api public
    def digest_auth(user:, pass:)
      use(digest_auth: { user: user, pass: pass })
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
    def retriable(tries: nil, delay: nil, exceptions: nil, retry_statuses: nil,
                  on_retry: nil, max_delay: nil, should_retry: nil)
      opts = { tries: tries, delay: delay, exceptions: exceptions, retry_statuses: retry_statuses,
               on_retry: on_retry, max_delay: max_delay, should_retry: should_retry }.compact
      branch default_options.with_retriable(opts.empty? || opts)
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
