# frozen_string_literal: true

require "forwardable"
require "time"

require "http/base64"
require "http/errors"
require "http/headers"
require "http/request/body"
require "http/request/proxy"
require "http/request/writer"
require "http/version"
require "http/uri"

module HTTP
  # Represents an HTTP request with verb, URI, headers, and body
  class Request
    extend Forwardable

    include HTTP::Base64
    include Proxy

    # The method given was not understood
    class UnsupportedMethodError < RequestError; end

    # The scheme of given URI was not understood
    class UnsupportedSchemeError < RequestError; end

    # Default User-Agent header value
    USER_AGENT = "http.rb/#{HTTP::VERSION}".freeze

    # Supported HTTP methods
    METHODS = [
      # RFC 2616: Hypertext Transfer Protocol -- HTTP/1.1
      :options, :get, :head, :post, :put, :delete, :trace, :connect,

      # RFC 2518: HTTP Extensions for Distributed Authoring -- WEBDAV
      :propfind, :proppatch, :mkcol, :copy, :move, :lock, :unlock,

      # RFC 3648: WebDAV Ordered Collections Protocol
      :orderpatch,

      # RFC 3744: WebDAV Access Control Protocol
      :acl,

      # RFC 6352: vCard Extensions to WebDAV -- CardDAV
      :report,

      # RFC 5789: PATCH Method for HTTP
      :patch,

      # draft-reschke-webdav-search: WebDAV Search
      :search,

      # RFC 4791: Calendaring Extensions to WebDAV -- CalDAV
      :mkcalendar,

      # Implemented by several caching servers, like Squid, Varnish or Fastly
      :purge
    ].freeze

    # Allowed schemes
    SCHEMES = %i[http https ws wss].freeze

    # Default ports of supported schemes
    PORTS = {
      http:  80,
      https: 443,
      ws:    80,
      wss:   443
    }.freeze

    # HTTP method as a lowercase symbol
    #
    # @example
    #   request.verb # => :get
    #
    # @return [Symbol]
    # @api public
    attr_reader :verb

    # URI scheme as a lowercase symbol
    #
    # @example
    #   request.scheme # => :https
    #
    # @return [Symbol]
    # @api public
    attr_reader :scheme

    # URI normalizer callable
    #
    # @example
    #   request.uri_normalizer
    #
    # @return [#call]
    # @api public
    attr_reader :uri_normalizer

    # Request URI
    #
    # @example
    #   request.uri # => #<HTTP::URI ...>
    #
    # @return [HTTP::URI]
    # @api public
    attr_reader :uri

    # Proxy configuration hash
    #
    # @example
    #   request.proxy
    #
    # @return [Hash]
    # @api public
    attr_reader :proxy

    # Request body object
    #
    # @example
    #   request.body
    #
    # @return [HTTP::Request::Body]
    # @api public
    attr_reader :body

    # The HTTP headers collection
    #
    # @example
    #   request.headers
    #
    # @return [HTTP::Headers]
    # @api public
    attr_reader :headers

    # HTTP version string
    #
    # @example
    #   request.version # => "1.1"
    #
    # @return [String]
    # @api public
    attr_reader :version

    # Create a new HTTP request
    #
    # @param [#to_s] verb HTTP request method
    # @param [HTTP::URI, #to_s] uri
    # @param [Hash] headers
    # @param [Hash] proxy
    # @param [String, Enumerable, IO, nil] body
    # @param [String] version
    # @param [#call] uri_normalizer
    #
    # @example
    #   Request.new(verb: :get, uri: "https://example.com")
    #
    # @return [HTTP::Request]
    # @api public
    def initialize(verb:, uri:, headers: nil, proxy: {}, body: nil, version: "1.1",
                   uri_normalizer: nil)
      @uri_normalizer = uri_normalizer || HTTP::URI::NORMALIZER
      @verb = verb.to_s.downcase.to_sym
      parse_uri!(uri)
      validate_method_and_scheme!

      @proxy   = proxy
      @version = version
      @headers = prepare_headers(headers)
      @body    = prepare_body(body)
    end

    # Returns new Request with updated uri
    #
    # @example
    #   request.redirect("https://example.com/new")
    #
    # @return [HTTP::Request]
    # @api public
    def redirect(uri, verb = @verb)
      redirect_uri = @uri.join(uri)
      headers = redirect_headers(redirect_uri, verb)
      new_body = verb == :get ? nil : body.source

      self.class.new(
        verb:           verb,
        uri:            redirect_uri,
        headers:        headers,
        proxy:          proxy,
        body:           new_body,
        version:        version,
        uri_normalizer: uri_normalizer
      )
    end

    # Stream the request to a socket
    #
    # @example
    #   request.stream(socket)
    #
    # @return [void]
    # @api public
    def stream(socket)
      include_proxy_headers if using_proxy? && !@uri.https?
      Request::Writer.new(socket, body, headers, headline).stream
    end

    # Is this request using a proxy?
    #
    # @example
    #   request.using_proxy?
    #
    # @return [Boolean]
    # @api public
    def using_proxy?
      proxy && proxy.keys.size >= 2
    end

    # Is this request using an authenticated proxy?
    #
    # @example
    #   request.using_authenticated_proxy?
    #
    # @return [Boolean]
    # @api public
    def using_authenticated_proxy?
      proxy && proxy.keys.size >= 4
    end

    # Compute HTTP request header for direct or proxy request
    #
    # @example
    #   request.headline
    #
    # @return [String]
    # @api public
    def headline
      request_uri =
        if using_proxy? && !uri.https?
          uri.omit(:fragment)
        else
          uri.request_uri
        end.to_s

      raise RequestError, "Invalid request URI: #{request_uri.inspect}" if request_uri.match?(/\s/)

      "#{verb.to_s.upcase} #{request_uri} HTTP/#{version}"
    end

    # Host for tcp socket
    #
    # @example
    #   request.socket_host
    #
    # @return [String]
    # @api public
    def socket_host
      using_proxy? ? proxy[:proxy_address] : host
    end

    # Port for tcp socket
    #
    # @example
    #   request.socket_port
    #
    # @return [Integer]
    # @api public
    def socket_port
      using_proxy? ? proxy[:proxy_port] : port
    end

    # Human-readable representation of base request info
    #
    # @example
    #
    #     req.inspect
    #     # => #<HTTP::Request/1.1 GET https://example.com>
    #
    # @return [String]
    # @api public
    def inspect
      "#<#{self.class}/#{@version} #{verb.to_s.upcase} #{uri}>"
    end

    private

    # Build headers for a redirect request
    #
    # Strips the Host header (it will be regenerated), sensitive credentials
    # on cross-origin redirects, and Content-Type on GET verb changes.
    #
    # @param [HTTP::URI] redirect_uri the target URI
    # @param [Symbol] verb the HTTP verb for the redirected request
    # @return [HTTP::Headers] headers for the redirect
    # @api private
    def redirect_headers(redirect_uri, verb)
      headers = self.headers.dup
      headers.delete(Headers::HOST)

      # Strip sensitive headers when redirecting to a different origin
      # (scheme + host + port) to prevent credential leakage.
      unless @uri.origin == redirect_uri.origin
        headers.delete(Headers::AUTHORIZATION)
        headers.delete(Headers::COOKIE)
      end

      headers.delete(Headers::CONTENT_TYPE) if verb == :get

      headers
    end

    # @!attribute [r] host
    #   Host from the URI
    #   @return [String]
    #   @api private
    def_delegator :@uri, :host

    # Return the port for the request URI
    # @return [Fixnum]
    # @api private
    def port
      @uri.port || @uri.default_port
    end

    # Build default Host header value
    # @return [String]
    # @api private
    def default_host_header_value
      value = PORTS[@scheme] == port ? host : "#{host}:#{port}"

      raise RequestError, "Invalid host: #{value.inspect}" if value.match?(/\s/)

      value
    end

    # Parse and normalize the URI, setting scheme
    # @return [void]
    # @api private
    def parse_uri!(uri)
      raise ArgumentError, "uri is nil" if uri.nil?
      raise ArgumentError, "uri is empty" if uri.is_a?(String) && uri.empty?

      @uri = @uri_normalizer.call(uri)
      @scheme = @uri.scheme.to_s.downcase.to_sym if @uri.scheme
    end

    # Validate HTTP method and URI scheme
    # @return [void]
    # @api private
    def validate_method_and_scheme!
      raise(UnsupportedMethodError, "unknown method: #{verb}") unless METHODS.include?(@verb)
      raise(HTTP::URI::InvalidError, "invalid URI: #{@uri}") unless @scheme
      raise(UnsupportedSchemeError, "unknown scheme: #{scheme}") unless SCHEMES.include?(@scheme)
    end

    # Coerce input into a Body object
    # @return [HTTP::Request::Body]
    # @api private
    def prepare_body(body)
      body.is_a?(Request::Body) ? body : Request::Body.new(body)
    end

    # Build headers with default values
    # @return [HTTP::Headers]
    # @api private
    def prepare_headers(headers)
      headers = HTTP::Headers.coerce(headers || {})

      headers[Headers::HOST]       ||= default_host_header_value
      headers[Headers::USER_AGENT] ||= USER_AGENT

      headers
    end
  end
end
