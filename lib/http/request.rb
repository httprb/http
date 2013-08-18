require 'http/request_stream'

module HTTP
  class Request
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

    # Method is given as a lowercase symbol e.g. :get, :post
    attr_reader :method

    # "Request URI" as per RFC 2616
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
    attr_reader :uri
    attr_reader :headers, :proxy, :body, :version

    # :nodoc:
    def initialize(method, uri, headers = {}, proxy = {}, body = nil, version = "1.1")
      @method = method.to_s.downcase.to_sym
      raise UnsupportedMethodError, "unknown method: #{method}" unless METHODS.include? @method

      @uri = uri.is_a?(URI) ? uri : URI(uri.to_s)

      @headers = {}
      headers.each do |name, value|
        name = name.to_s
        key = name[CANONICAL_HEADER]
        key ||= Http.canonicalize_header(name)
        @headers[key] = value
      end

      @proxy, @body, @version = proxy, body, version
    end

    # Obtain the given header
    def [](header)
      @headers[Http.canonicalize_header(header)]
    end

    # Stream the request to a socket
    def stream(socket)
      path = uri.query ? "#{uri.path}?#{uri.query}" : uri.path
      path = "/" if path.empty?
      request_header = "#{method.to_s.upcase} #{path} HTTP/#{version}"
      rs = Http::RequestStream.new socket, body, @headers, request_header
      rs.stream
    end
  end
end
