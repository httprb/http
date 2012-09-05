module Http
  class RequestStream
    def initialize(socket, body, headers, headerstart)
      raise ArgumentError unless [String, Enumerable, NilClass].include? body.class
      @socket         = socket
      @body           = body
      @headers        = headers
      @request_header = [headerstart]
    end

    #Adds headers to the request header from the headers array
    def add_headers
      @headers.each do |field, value|
        @request_header << "#{field}: #{value}"
      end
    end

    # Stream the request to a socket
    def stream
      self.send_request_header
      self.send_request_body
    end

    # Adds the headers to the header array for the given request body we are working
    # with
    def add_body_type_headers
      if @body.class == String and not @headers['Content-Length']
        @request_header << "Content-Length: #{@body.length}"
      elsif @body.class == Enumerable
        if encoding = @headers['Transfer-Encoding'] and not encoding == "chunked"
          raise ArgumentError, "invalid transfer encoding"
        else
          @request_header << "Transfer-Encoding: chunked"
        end
      end
    end

    # Joins the headers specified in the request into a correctly formatted
    # http request header string
    def join_headers
      # join the headers array with crlfs, stick two on the end because
      # that ends the request header
      @request_header.join(CRLF) + (CRLF)*2
    end

    def send_request_header
      self.add_headers
      self.add_body_type_headers
      header = self.join_headers

      @socket << header
    end

    def send_request_body
      if @body.class == String
        @socket << @body
      elsif @body.class == Enumerable
        @body.each do |chunk|
          @socket << chunk.bytesize.to_s(16) << CRLF
          @socket << chunk
        end

        @socket << "0" << CRLF * 2
      end
    end
  end
end
