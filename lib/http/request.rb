require "forwardable"
require "base64"
require "time"

require "http/errors"
require "http/headers"
require "http/request/caching"
require "http/request/writer"
require "http/version"
require "http/uri"

module HTTP
  class Request
    extend Forwardable

    include HTTP::Headers::Mixin

    # The method given was not understood
    class UnsupportedMethodError < RequestError; end

    # The scheme of given URI was not understood
    class UnsupportedSchemeError < RequestError; end

    # Default User-Agent header value
    USER_AGENT = "RubyHTTPGem/#{HTTP::VERSION}".freeze

    # RFC 2616: Hypertext Transfer Protocol -- HTTP/1.1
    METHODS = [:options, :get, :head, :post, :put, :delete, :trace, :connect]

    # RFC 2518: HTTP Extensions for Distributed Authoring -- WEBDAV
    METHODS.concat [:propfind, :proppatch, :mkcol, :copy, :move, :lock, :unlock]

    # RFC 3648: WebDAV Ordered Collections Protocol
    METHODS.concat [:orderpatch]

    # RFC 3744: WebDAV Access Control Protocol
    METHODS.concat [:acl]

    # draft-dusseault-http-patch: PATCH Method for HTTP
    METHODS.concat [:patch]

    # draft-reschke-webdav-search: WebDAV Search
    METHODS.concat [:search]

    # Allowed schemes
    SCHEMES = [:http, :https, :ws, :wss]

    # Default ports of supported schemes
    PORTS = {
      :http   => 80,
      :https  => 443,
      :ws     => 80,
      :wss    => 443
    }

    # Method is given as a lowercase symbol e.g. :get, :post
    attr_reader :verb

    # Scheme is normalized to be a lowercase symbol e.g. :http, :https
    attr_reader :scheme

    # The following alias may be removed in two minor versions (0.8.0) or one
    # major version (1.0.0)
    def __method__(*args)
      warn "#{Kernel.caller.first}: [DEPRECATION] HTTP::Request#__method__ is deprecated. Use #method instead."
      method(*args)
    end

    # "Request URI" as per RFC 2616
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
    attr_reader :uri
    attr_reader :proxy, :body, :version

    # :nodoc:
    def initialize(verb, uri, headers = {}, proxy = {}, body = nil, version = "1.1") # rubocop:disable ParameterLists
      @verb   = verb.to_s.downcase.to_sym
      @uri    = HTTP::URI.parse uri
      @scheme = @uri.scheme && @uri.scheme.to_s.downcase.to_sym

      fail(UnsupportedMethodError, "unknown method: #{verb}") unless METHODS.include?(@verb)
      fail(UnsupportedSchemeError, "unknown scheme: #{scheme}") unless SCHEMES.include?(@scheme)

      @proxy, @body, @version = proxy, body, version

      @headers = HTTP::Headers.coerce(headers || {})

      @headers["Host"]        ||= default_host_header_value
      @headers["User-Agent"]  ||= USER_AGENT
    end

    # Returns new Request with updated uri
    def redirect(uri, verb = @verb)
      req = self.class.new(verb, @uri.join(uri), headers, proxy, body, version)
      req["Host"] = req.uri.host
      req
    end

    # Stream the request to a socket
    def stream(socket)
      include_proxy_authorization_header if using_authenticated_proxy? && !@uri.https?
      Request::Writer.new(socket, body, headers, request_header).stream
    end

    # Is this request using a proxy?
    def using_proxy?
      proxy && proxy.keys.size >= 2
    end

    # Is this request using an authenticated proxy?
    def using_authenticated_proxy?
      proxy && proxy.keys.size == 4
    end

    # Compute and add the Proxy-Authorization header
    def include_proxy_authorization_header
      headers["Proxy-Authorization"] = proxy_authorization_header
    end

    def proxy_authorization_header
      digest = Base64.strict_encode64("#{proxy[:proxy_username]}:#{proxy[:proxy_password]}")
      "Basic #{digest}"
    end

    # Setup tunnel through proxy for SSL request
    def connect_using_proxy(socket)
      Request::Writer.new(socket, nil, proxy_connect_headers, proxy_connect_header).connect_through_proxy
    end

    # Compute HTTP request header for direct or proxy request
    def request_header
      "#{verb.to_s.upcase} #{uri.normalize} HTTP/#{version}"
    end

    # Compute HTTP request header SSL proxy connection
    def proxy_connect_header
      "CONNECT #{@uri.host}:#{@uri.port} HTTP/#{version}"
    end

    # Headers to send with proxy connect request
    def proxy_connect_headers
      connect_headers = HTTP::Headers.coerce(
        "Host" => headers["Host"],
        "User-Agent" => headers["User-Agent"]
      )
      connect_headers["Proxy-Authorization"] = proxy_authorization_header if using_authenticated_proxy?
      connect_headers
    end

    # Host for tcp socket
    def socket_host
      using_proxy? ? proxy[:proxy_address] : host
    end

    # Port for tcp socket
    def socket_port
      using_proxy? ? proxy[:proxy_port] : port
    end

    # @return [HTTP::Request::Caching]
    def caching
      Caching.new self
    end

    private

    # @!attribute [r] host
    #   @return [String]
    def_delegator :@uri, :host

    # @!attribute [r] port
    #   @return [Fixnum]
    def port
      @uri.port || @uri.default_port
    end

    # @return [String] Default host (with port if needed) header value.
    def default_host_header_value
      PORTS[@scheme] != port ? "#{host}:#{port}" : host
    end
  end
end
