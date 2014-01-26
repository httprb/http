module HTTP
  class Response
    class Parser
      attr_reader :socket, :connection

      def initialize(connection)
        @parser      = HTTP::Parser.new(self)
        @connection  = connection
        @socket      = connection.socket
        @buffer_size = connection.buffer_size
        @currently_reading = @currently_requesting = nil
        @pending_reads     = []
        @pending_requests  = []

        reset
      end

      def add(data)
        @parser << data
      end
      alias_method :<<, :add

      def http_method
        @parser.http_method
      end

      def http_version
        @parser.http_version[1] == 1 ? HTTP_VERSION_1_1 : HTTP_VERSION_1_0
      end

      def url
        @parser.response_url
      end

      def current_response
        until @currently_requesting || @currently_reading
          readpartial
        end
        @currently_requesting || @currently_reading
      end

      def readpartial(size = @buffer_size)
        bytes = @socket.readpartial(size)
        @parser << bytes
      end

      #
      # HTTP::Parser callbacks
      #
      def on_headers_complete(headers)
        info = Info.new(http_method, url, http_version, headers)
        resp = Response.new(info, connection)

        if @currently_reading
          @pending_reads << resp
        else
          @currently_reading = resp
        end
      end

      # Send body directly to HTTP::Response to be buffered.
      def on_body(chunk)
        @currently_reading.fill_buffer(chunk)
      end

      # Mark current response as complete, set this as ready to respond.
      def on_message_complete
        @currently_reading.finish_reading! if @currently_reading.is_a?(Response)

        if @currently_requesting
          @pending_requests << @currently_reading
        else
          @currently_requesting = @currently_reading
        end

        @currently_reading = @pending_reads.shift
      end

      def reset
        popped = @currently_requesting

        if req = @pending_requests.shift
          @currently_requesting = req
        elsif @currently_requesting
          @currently_requesting = nil
        end

        popped
      end
    end
  end
end
