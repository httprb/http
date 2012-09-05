module Http
  class Request
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
      request_header = "#{method.to_s.upcase} #{uri.path} HTTP/#{version}"
      rs = Http::RequestStream.new socket, body, @headers, request_header
      rs.stream
    end
  end
end
