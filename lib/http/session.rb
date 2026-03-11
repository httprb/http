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
  # @example Reuse a configured session across threads
  #   session = HTTP.headers("Accept" => "application/json").timeout(10)
  #   threads = 5.times.map do
  #     Thread.new { session.get("https://example.com") }
  #   end
  #   threads.each(&:join)
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
    end

    # Make an HTTP request by creating a new {Client}
    #
    # A fresh {Client} is created for each request, ensuring thread safety.
    # Manages cookies across redirect hops when following redirects.
    #
    # @example
    #   session = HTTP::Session.new
    #   session.request(:get, "https://example.com")
    #
    # @param verb [Symbol] the HTTP method
    # @param uri [#to_s] the URI to request
    # @return [HTTP::Response] the response
    # @api public
    def request(verb, uri,
                headers: nil, params: nil, form: nil, json: nil, body: nil,
                response: nil, encoding: nil, follow: nil, ssl: nil, ssl_context: nil,
                proxy: nil, nodelay: nil, features: nil, retriable: nil,
                socket_class: nil, ssl_socket_class: nil, timeout_class: nil,
                timeout_options: nil, keep_alive_timeout: nil, base_uri: nil, persistent: nil)
      cookie_jar = CookieJar.new
      merged = default_options.merge(
        { headers: headers, params: params, form: form, json: json, body: body,
          response: response, encoding: encoding, follow: follow, ssl: ssl,
          ssl_context: ssl_context, proxy: proxy, nodelay: nodelay, features: features,
          retriable: retriable, socket_class: socket_class, ssl_socket_class: ssl_socket_class,
          timeout_class: timeout_class, timeout_options: timeout_options,
          keep_alive_timeout: keep_alive_timeout, base_uri: base_uri, persistent: persistent }.compact
      )
      builder = Request::Builder.new(merged)
      client  = make_client(default_options)

      req = builder.build(verb, uri)
      load_cookies(cookie_jar, req)
      res = client.perform(req, merged)
      store_cookies(cookie_jar, res)

      return res unless merged.follow

      perform_redirects(cookie_jar, client, req, res, merged)
    end

    private

    # Follow redirects with cookie management
    #
    # @param jar [HTTP::CookieJar] the cookie jar
    # @param client [HTTP::Client] the client to perform requests
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
        response = client.perform(wrapped, opts)
        store_cookies(jar, response)
        response
      end
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
