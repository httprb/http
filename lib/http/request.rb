require 'http/header'
require 'http/request_stream'
require 'uri'

module HTTP
  class Request
    include HTTP::Header

    # The method given was not understood
    class UnsupportedMethodError < ArgumentError; end

    # The scheme of given URI was not understood
    class UnsupportedSchemeError < ArgumentError; end

    # Prefix for relative URLs
    PREFIX_RE = %r{^[^:]+://[^/]+}

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
    SCHEMES = [:http, :https]

    # Method is given as a lowercase symbol e.g. :get, :post
    attr_reader :verb

    # Scheme is normalized to be a lowercase symbol e.g. :http, :https
    attr_reader :scheme

    # The following alias may be removed in three minor versions (0.8.0) or one
    # major version (1.0.0)
    alias_method :__method__, :method

    # The following method may be removed in two minor versions (0.7.0) or one
    # major version (1.0.0)
    def method(*args)
      warn "#{Kernel.caller.first}: [DEPRECATION] HTTP::Request#method is deprecated. Use #verb instead. For Object#method, use #__method__."
      @verb
    end

    # "Request URI" as per RFC 2616
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
    attr_reader :uri
    attr_reader :headers, :body, :version

    # :nodoc:
    def initialize(verb, uri, headers = {}, body = nil, version = '1.1') # rubocop:disable ParameterLists
      @verb   = verb.to_s.downcase.to_sym
      @uri    = uri.is_a?(URI) ? uri : URI(uri.to_s)
      @scheme = @uri.scheme.to_s.downcase.to_sym if @uri.scheme

      fail(UnsupportedMethodError, "unknown method: #{verb}") unless METHODS.include?(@verb)
      fail(UnsupportedSchemeError, "unknown scheme: #{@uri.scheme}") unless SCHEMES.include?(scheme)

      @headers = {}
      headers.each do |name, value|
        name = name.to_s
        key = name[CANONICAL_HEADER]
        key ||= canonicalize_header(name)
        @headers[key] = value
      end
      @headers['Host'] ||= @uri.host

      @body, @version = body, version
    end

    # Returns new Request with updated uri
    def redirect(uri)
      uri = "#{@uri.to_s[PREFIX_RE]}#{uri}" unless uri.to_s[PREFIX_RE]
      req = self.class.new(verb, uri, headers, body, version)
      req.headers['Host'] = req.uri.host
      req
    end

    # Obtain the given header
    def [](header)
      @headers[canonicalize_header(header)]
    end

    # Stream the request to a socket
    def stream(socket)
      path = uri.query && !uri.query.empty? ? "#{uri.path}?#{uri.query}" : uri.path
      path = '/' if path.empty?
      request_header = "#{verb.to_s.upcase} #{path} HTTP/#{version}"
      rs = HTTP::RequestStream.new socket, body, @headers, request_header
      rs.stream
    end
  end
end
