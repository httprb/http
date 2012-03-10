module Http
  class Request
    # Method is given as a lowercase symbol e.g. :get, :post
    attr_reader :method

    # "Request URI" as per RFC 2616
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
    attr_reader :uri
    attr_reader :headers, :body, :version

    # :nodoc:
    def initialize(method, uri, headers = {}, body = nil, version = "1.1")
      @method = method.to_s.downcase.to_sym
      raise UnsupportedMethodError, "unknown method: #{method}" unless METHODS.include? @method

      @uri = uri.is_a?(URI) ? uri : URI(uri.to_s)

      @headers = {}
      headers.each do |name, value|
        unless name =~ /proxy/
          name = name.to_s
          key = name[CANONICAL_HEADER]
          key ||= Http.canonicalize_header(name)
          @headers[key] = value
        end
      end      
      
      @body, @version = body, version
    end

    # Obtain the given header
    def [](header)
      @headers[Http.canonicalize_header(header)]
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
