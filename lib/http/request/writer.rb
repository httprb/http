# frozen_string_literal: true

require "http/headers"

module HTTP
  class Request
    # Streams HTTP requests to a socket
    class Writer
      # CRLF is the universal HTTP delimiter
      CRLF = "\r\n"

      # Chunked data terminator
      ZERO = "0"

      # End of a chunked transfer
      CHUNKED_END = "#{ZERO}#{CRLF}#{CRLF}".freeze

      # Initialize a new request writer
      #
      # @example
      #   Writer.new(socket, body, headers, "GET / HTTP/1.1")
      #
      # @return [HTTP::Request::Writer]
      # @api public
      def initialize(socket, body, headers, headline)
        @body           = body
        @socket         = socket
        @headers        = headers
        @request_header = [headline]
      end

      # Adds headers to the request header array
      #
      # @example
      #   writer.add_headers
      #
      # @return [void]
      # @api public
      def add_headers
        @headers.each do |field, value|
          @request_header << "#{field}: #{value}"
        end
      end

      # Stream the request to a socket
      #
      # @example
      #   writer.stream
      #
      # @return [void]
      # @api public
      def stream
        add_headers
        add_body_type_headers
        send_request
      end

      # Send headers needed to connect through proxy
      #
      # @example
      #   writer.connect_through_proxy
      #
      # @return [void]
      # @api public
      def connect_through_proxy
        add_headers
        write(join_headers)
      end

      # Adds content length or transfer encoding headers
      #
      # @example
      #   writer.add_body_type_headers
      #
      # @return [void]
      # @api public
      def add_body_type_headers
        return if @headers[Headers::CONTENT_LENGTH] || chunked? || (
          @body.source.nil? && %w[GET HEAD DELETE CONNECT].any? do |method|
            @request_header[0].start_with?("#{method} ")
          end
        )

        @request_header << "#{Headers::CONTENT_LENGTH}: #{@body.size}"
      end

      # Joins headers into an HTTP request header string
      #
      # @example
      #   writer.join_headers
      #
      # @return [String]
      # @api public
      def join_headers
        # join the headers array with crlfs, stick two on the end because
        # that ends the request header
        @request_header.join(CRLF) + (CRLF * 2)
      end

      # Writes HTTP request data into the socket
      #
      # @example
      #   writer.send_request
      #
      # @return [void]
      # @api public
      def send_request
        each_chunk { |chunk| write chunk }
      rescue Errno::EPIPE
        # server doesn't need any more data
        nil
      end

      # Yields chunks of request data for the socket
      #
      # It's important to send the request in a single write call when possible
      # in order to play nicely with Nagle's algorithm. Making two writes in a
      # row triggers a pathological case where Nagle is expecting a third write
      # that never happens.
      #
      # @example
      #   writer.each_chunk { |chunk| socket.write(chunk) }
      #
      # @return [void]
      # @api public
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

      # Returns chunk encoded per Transfer-Encoding header
      #
      # @example
      #   writer.encode_chunk("hello")
      #
      # @return [String]
      # @api public
      def encode_chunk(chunk)
        if chunked?
          chunk.bytesize.to_s(16) << CRLF << chunk << CRLF
        else
          chunk
        end
      end

      # Returns true if using chunked transfer encoding
      #
      # @example
      #   writer.chunked?
      #
      # @return [Boolean]
      # @api public
      def chunked?
        @headers[Headers::TRANSFER_ENCODING] == Headers::CHUNKED
      end

      private

      # Write data to the underlying socket
      # @return [void]
      # @raise [SocketWriteError] when unable to write to socket
      # @api private
      def write(data)
        until data.empty?
          length = @socket.write(data)
          break unless data.bytesize > length

          data = data.byteslice(length..-1)
        end
      rescue Errno::EPIPE
        raise
      rescue IOError, SocketError, SystemCallError => e
        raise SocketWriteError, "error writing to socket: #{e}", e.backtrace
      end
    end
  end
end
