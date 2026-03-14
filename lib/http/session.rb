# frozen_string_literal: true

require "forwardable"

require "http/cookie_jar"
require "http/headers"
require "http/redirector"
require "http/request/builder"

module HTTP
  # Thread-safe options builder for configuring HTTP requests.
  #
  # Session objects are returned by all chainable configuration methods
  # (e.g., {Chainable#headers}, {Chainable#timeout}, {Chainable#cookies}).
  # They hold an immutable {Options} object and create a new {Client}
  # for each request, making them safe to share across threads.
  #
  # When configured for persistent connections (via {Chainable#persistent}),
  # the session maintains a pool of {Client} instances keyed by origin,
  # enabling connection reuse within the same origin and transparent
  # cross-origin redirect handling.
  #
  # @example Reuse a configured session across threads
  #   session = HTTP.headers("Accept" => "application/json").timeout(10)
  #   threads = 5.times.map do
  #     Thread.new { session.get("https://example.com") }
  #   end
  #   threads.each(&:join)
  #
  # @example Persistent session with cross-origin redirects
  #   HTTP.persistent("https://example.com").follow do |http|
  #     http.get("/redirect-to-other-domain")  # follows cross-origin redirect
  #   end
  #
  # @see Chainable
  # @see Client
  class Session
    extend Forwardable
    include Chainable

    # @!method persistent?
    #   Indicate whether the session has persistent connection options
    #
    #   @example
    #     session = HTTP::Session.new(persistent: "http://example.com")
    #     session.persistent?
    #
    #   @see Options#persistent?
    #   @return [Boolean]
    #   @api public
    def_delegator :default_options, :persistent?

    # Initialize a new Session
    #
    # @example
    #   session = HTTP::Session.new(headers: {"Accept" => "application/json"})
    #
    # @param default_options [HTTP::Options, nil] existing options instance
    # @param options [Hash] keyword options (see HTTP::Options#initialize)
    # @return [HTTP::Session] a new session instance
    # @api public
    def initialize(default_options = nil, **)
      @default_options = HTTP::Options.new(default_options, **)
      @clients = {}
    end

    # Close all persistent connections held by this session
    #
    # When the session is persistent, this closes every pooled {Client}
    # and clears the pool. Safe to call on non-persistent sessions (no-op).
    #
    # @example
    #   session = HTTP.persistent("https://example.com")
    #   session.get("/")
    #   session.close
    #
    # @return [void]
    # @api public
    def close
      @clients.each_value(&:close)
      @clients.clear
    end

    # Make an HTTP request
    #
    # For non-persistent sessions a fresh {Client} is created for each
    # request, ensuring thread safety. For persistent sessions the pooled
    # {Client} for the request's origin is reused.
    #
    # Manages cookies across redirect hops when following redirects.
    #
    # @example Without a block
    #   session = HTTP::Session.new
    #   session.request(:get, "https://example.com")
    #
    # @example With a block (auto-closes connection)
    #   session = HTTP::Session.new
    #   session.request(:get, "https://example.com") { |res| res.status }
    #
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @yieldparam response [HTTP::Response] the response
    # @return [HTTP::Response, Object] the response, or block return value
    # @api public
    def request(verb, uri,
                headers: nil, params: nil, form: nil, json: nil, body: nil,
                response: nil, encoding: nil, follow: nil, ssl: nil, ssl_context: nil,
                proxy: nil, nodelay: nil, features: nil, retriable: nil,
                socket_class: nil, ssl_socket_class: nil, timeout_class: nil,
                timeout_options: nil, keep_alive_timeout: nil, base_uri: nil, persistent: nil, &block)
      merged = default_options.merge(
        { headers: headers, params: params, form: form, json: json, body: body,
          response: response, encoding: encoding, follow: follow, ssl: ssl,
          ssl_context: ssl_context, proxy: proxy, nodelay: nodelay, features: features,
          retriable: retriable, socket_class: socket_class, ssl_socket_class: ssl_socket_class,
          timeout_class: timeout_class, timeout_options: timeout_options,
          keep_alive_timeout: keep_alive_timeout, base_uri: base_uri, persistent: persistent }.compact
      )
      client = persistent? ? nil : make_client(default_options)
      res    = perform_request(client, verb, uri, merged)

      return res unless block

      yield res
    ensure
      if block
        persistent? ? close : client&.close
      end
    end

    private

    # Execute a request with cookie management
    #
    # @param client [HTTP::Client, nil] the client (nil when persistent; looked up from pool)
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @param merged [HTTP::Options] the merged options
    # @return [HTTP::Response] the response
    # @api private
    def perform_request(client, verb, uri, merged)
      cookie_jar = CookieJar.new
      builder = Request::Builder.new(merged)
      req = builder.build(verb, uri)
      client ||= client_for_origin(req.uri.origin)
      load_cookies(cookie_jar, req)
      res = client.perform(req, merged)
      store_cookies(cookie_jar, res)

      return res unless merged.follow

      perform_redirects(cookie_jar, client, req, res, merged)
    end

    # Follow redirects with cookie management
    #
    # For persistent sessions, each redirect hop may target a different
    # origin. The session looks up (or creates) a pooled {Client} for
    # the redirect target's origin, allowing cross-origin redirects
    # without raising {StateError}.
    #
    # @param jar [HTTP::CookieJar] the cookie jar
    # @param client [HTTP::Client] the client for the initial request
    # @param req [HTTP::Request] the original request
    # @param res [HTTP::Response] the initial redirect response
    # @param opts [HTTP::Options] the merged options
    # @return [HTTP::Response] the final non-redirect response
    # @api private
    def perform_redirects(jar, client, req, res, opts)
      builder = Request::Builder.new(opts)
      follow = opts.follow || {} #: Hash[untyped, untyped]
      Redirector.new(**follow).perform(req, res) do |redirect_req|
        wrapped = builder.wrap(redirect_req)
        apply_cookies(jar, wrapped)
        apply_cookies(jar, redirect_req)
        response = redirect_client(client, wrapped).perform(wrapped, opts)
        store_cookies(jar, response)
        response
      end
    end

    # Return the appropriate client for a redirect hop
    #
    # @param client [HTTP::Client] the client for the original request
    # @param request [HTTP::Request] the redirect request
    # @return [HTTP::Client] the client for the redirect target
    # @api private
    def redirect_client(client, request)
      persistent? ? client_for_origin(request.uri.origin) : client
    end

    # Return a pooled persistent {Client} for the given origin
    #
    # Creates a new {Client} if one does not already exist for this origin.
    # For the session's primary persistent origin, the default options are
    # used directly. For other origins (e.g. redirect targets), the
    # persistent origin is overridden and base_uri is cleared.
    #
    # @param origin [String] the URI origin (scheme + host + port)
    # @return [HTTP::Client] a persistent client for the origin
    # @api private
    def client_for_origin(origin)
      @clients[origin] ||= make_client(options_for_origin(origin))
    end

    # Build {Options} for a persistent client targeting the given origin
    #
    # @param origin [String] the URI origin
    # @return [HTTP::Options] options configured for this origin
    # @api private
    def options_for_origin(origin)
      return default_options if origin == default_options.persistent

      default_options.merge(persistent: origin, base_uri: nil)
    end

    # Load cookies from the request's Cookie header into the jar
    #
    # @param jar [HTTP::CookieJar] the cookie jar
    # @param request [HTTP::Request] the request
    # @return [void]
    # @api private
    def load_cookies(jar, request)
      header = request.headers[Headers::COOKIE]
      cookies = HTTP::Cookie.cookie_value_to_hash(header.to_s)

      cookies.each do |name, value|
        jar.add(HTTP::Cookie.new(name, value, path: request.uri.path, domain: request.host))
      end
    end

    # Store cookies from the response's Set-Cookie headers into the jar
    #
    # @param jar [HTTP::CookieJar] the cookie jar
    # @param response [HTTP::Response] the response
    # @return [void]
    # @api private
    def store_cookies(jar, response)
      response.cookies.each do |cookie|
        if cookie.value == ""
          jar.delete(cookie)
        else
          jar.add(cookie)
        end
      end
    end

    # Apply cookies from the jar to the request's Cookie header
    #
    # @param jar [HTTP::CookieJar] the cookie jar
    # @param request [HTTP::Request] the request
    # @return [void]
    # @api private
    def apply_cookies(jar, request)
      if jar.empty?
        request.headers.delete(Headers::COOKIE)
      else
        request.headers.set(Headers::COOKIE, jar.map { |c| "#{c.name}=#{c.value}" }.join("; "))
      end
    end
  end
end
