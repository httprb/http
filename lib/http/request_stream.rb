module Http
  class RequestStream
    def initialize(socket, body, headers, headerstart)
      @socket         = socket
      @body           = body
      @headers        = headers
      @request_header = headerstart
    end

    # Stream the request to a socket
    def stream
      socket = @socket
      request_header = @request_header
      @headers.each do |field, value|
        request_header << "#{field}: #{value}#{CRLF}"
      end

      case @body
      when NilClass
        socket << request_header << CRLF
      when String
        request_header << "Content-Length: #{@body.length}#{CRLF}" unless @headers['Content-Length']
        request_header << CRLF

        socket << request_header
        socket << @body
      when Enumerable
        if encoding = @headers['Transfer-Encoding']
          raise ArgumentError, "invalid transfer encoding" unless encoding == "chunked"
          request_header << CRLF
        else
          request_header << "Transfer-Encoding: chunked#{CRLF * 2}"
        end

        socket << request_header
        @body.each do |chunk|
          socket << chunk.bytesize.to_s(16) << CRLF
          socket << chunk
        end

        socket << "0" << CRLF * 2
      else raise TypeError, "invalid @body type: #{@body.class}"
      end
    end
  end
end
