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
      request_header = "#{method.to_s.upcase} #{uri} HTTP/#{version}#{CRLF}"
      @headers.each do |field, value|
        request_header << "#{field}: #{value}#{CRLF}"
      end

      unless body
        socket << request_header << CRLF
        return
      end

      socket << request_header

      if body.respond_to? :each
        encoding = @headers['Transfer-Encoding']
        if encoding
          raise ArgumentError, "invalid transfer encoding" unless encoding == "chunked"
          socket << CRLF
        else
          socket << "Transfer-Encoding: chunked#{CRLF * 2}"
        end

        body.each do |chunk|
          socket << chunk.bytesize.to_s(16) << CRLF
          socket << chunk
        end

        socket << "0" << CRLF * 2
      else
        socket << "Content-Length: #{body.length}#{CRLF}" unless @headers['Content-Length']
        socket << CRLF
        socket << body.to_s
        socket << CRLF
      end
    end

    # Create a Net::HTTP request from this request
    def to_net_http_request
      request_class = Net::HTTP.const_get(@method.to_s.capitalize)

      request = request_class.new(@uri.request_uri, @headers)

      request.body = @body
      request
    end
  end
end
