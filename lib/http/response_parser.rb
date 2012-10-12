module HTTP
  class Response
    class Parser
      attr_reader :headers

      def initialize
        @parser = Http::Parser.new(self)
        reset
      end

      def add(data)
        @parser << data
      end
      alias_method :<<, :add

      def headers?
        !!@headers
      end

      def http_version
        @parser.http_version.join(".")
      end

      def status_code
        @parser.status_code
      end

      #
      # Http::Parser callbacks
      #

      def on_headers_complete(headers)
        @headers = headers
      end

      def on_body(chunk)
        if @chunk
          @chunk << chunk
        else
          @chunk = chunk
        end
      end

      def chunk
        if (chunk = @chunk)
          @chunk = nil
          chunk
        end
      end

      def on_message_complete
        @finished = true
      end

      def reset
        @finished = false
        @headers  = nil
        @chunk    = nil
      end
    end
  end
end
