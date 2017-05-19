# frozen_string_literal: true
require "http/headers"
require "http/request/body"

module HTTP
  class Request
    class Writer
      # CRLF is the universal HTTP delimiter
      CRLF = "\r\n".freeze

      # Chunked data termintaor.
      ZERO = "0".freeze

      # Chunked transfer encoding
      CHUNKED = "chunked".freeze

      # End of a chunked transfer
      CHUNKED_END = "#{ZERO}#{CRLF}#{CRLF}".freeze

      def initialize(socket, body, headers, headline)
        @body           = Body.new(body)
        @socket         = socket
        @headers        = headers
        @request_header = [headline]
      end

      # Adds headers to the request header from the headers array
      def add_headers
        @headers.each do |field, value|
          @request_header << "#{field}: #{value}"
        end
      end

      # Stream the request to a socket
      def stream
        add_headers
        add_body_type_headers
        send_request
      end

      # Send headers needed to connect through proxy
      def connect_through_proxy
        add_headers
        write(join_headers)
      end

      # Adds the headers to the header array for the given request body we are working
      # with
      def add_body_type_headers
        return if @headers[Headers::CONTENT_LENGTH] || chunked?

        @request_header << "#{Headers::CONTENT_LENGTH}: #{@body.size}"
      end

      # Joins the headers specified in the request into a correctly formatted
      # http request header string
      def join_headers
        # join the headers array with crlfs, stick two on the end because
        # that ends the request header
        @request_header.join(CRLF) + CRLF * 2
      end

      def send_request
        headers = join_headers
        chunks = @body.each

        # It's important to send the request in a single write call when
        # possible in order to play nicely with Nagle's algorithm. Making
        # two writes in a row triggers a pathological case where Nagle is
        # expecting a third write that never happens.
        begin
          first_chunk = encode_chunk(chunks.next)
          write(headers << first_chunk)
        rescue StopIteration
          write(headers)
        end

        # Kernel#loop automatically rescues StopIteration
        loop do
          data = encode_chunk(chunks.next)
          write(data)
        end

        write(CHUNKED_END) if chunked?
      end

      # Returns the chunk encoded for to the specified "Transfer-Encoding" header.
      def encode_chunk(chunk)
        if chunked?
          chunk.bytesize.to_s(16) << CRLF << chunk << CRLF
        else
          chunk
        end
      end

      # Returns true if the request should be sent in chunked encoding.
      def chunked?
        @headers[Headers::TRANSFER_ENCODING] == CHUNKED
      end

      private

      def write(data)
        until data.empty?
          length = @socket.write(data)
          break unless data.bytesize > length
          data = data.byteslice(length..-1)
        end
      end
    end
  end
end
