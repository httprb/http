module Http
  class RequestStream
    def initialize(socket, body, headers, headerstart)
      raise ArgumentError unless [String, Enumerable, NilClass].include? body.class
      @socket         = socket
      @body           = body
      @headers        = headers
      @request_header = [headerstart]
    end

    def add_headers
      @headers.each do |field, value|
        @request_header << "#{field}: #{value}"
      end
    end

    def add_body_type_headers
      case @body
      when String
        @request_header << "Content-Length: #{@body.length}" unless @headers['Content-Length']
      when Enumerable
        if encoding = @headers['Transfer-Encoding']
          raise ArgumentError, "invalid transfer encoding" unless encoding == "chunked"
        else
          @request_header << "Transfer-Encoding: chunked"
        end
      end
    end

    def join_headers
      # join the headers array with crlfs, stick two on the end because
      # that ends the request header
      @request_header.join(CRLF) + (CRLF)*2
    end

    # Stream the request to a socket
    def stream
      self.add_headers
      self.add_body_type_headers
      header = self.join_headers

      @socket << header
      case @body
      when String
        @socket << @body
      when Enumerable
        @body.each do |chunk|
          @socket << chunk.bytesize.to_s(16) << CRLF
          @socket << chunk
        end

        @socket << "0" << CRLF * 2
      end
    end
  end
end
