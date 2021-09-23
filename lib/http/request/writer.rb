# frozen_string_literal: true

require "http/headers"

module HTTP
  class Request
    class Writer
      # CRLF is the universal HTTP delimiter
      CRLF = "\r\n"

      # Chunked data termintaor.
      ZERO = "0"

      # Chunked transfer encoding
      CHUNKED = "chunked"

      # End of a chunked transfer
      CHUNKED_END = "#{ZERO}#{CRLF}#{CRLF}"

      def initialize(socket, body, headers, headline)
        @body           = body
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
        return if @headers[Headers::CONTENT_LENGTH] || chunked? || (
          @body.source.nil? && %w[GET HEAD DELETE CONNECT].any? do |method|
            @request_header[0].start_with?("#{method} ")
          end
        )

        @request_header << "#{Headers::CONTENT_LENGTH}: #{@body.size}"
      end

      # Joins the headers specified in the request into a correctly formatted
      # http request header string
      def join_headers
        # join the headers array with crlfs, stick two on the end because
        # that ends the request header
        @request_header.join(CRLF) + (CRLF * 2)
      end

      # Writes HTTP request data into the socket.
      def send_request
        each_chunk { |chunk| write chunk }
      rescue Errno::EPIPE
        # server doesn't need any more data
        nil
      end

      # Yields chunks of request data that should be sent to the socket.
      #
      # It's important to send the request in a single write call when possible
      # in order to play nicely with Nagle's algorithm. Making two writes in a
      # row triggers a pathological case where Nagle is expecting a third write
      # that never happens.
      def each_chunk
        data = join_headers

        @body.each do |chunk|
          data << encode_chunk(chunk)
          yield data
          data.clear
        end

        yield data unless data.empty?

        yield CHUNKED_END if chunked?
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
      rescue Errno::EPIPE
        raise
      rescue IOError, SocketError, SystemCallError => e
        raise ConnectionError, "error writing to socket: #{e}", e.backtrace
      end
    end
  end
end
