require 'forwardable'

module HTTP
  class Response
    # A streamable response body, also easily converted into a string
    class Body
      extend Forwardable
      include Enumerable
      def_delegator :to_s, :empty?

      def initialize(client)
        @client    = client
        @streaming = nil
        @contents  = nil
      end

      # Read up to length bytes, but return any data that's available
      def readpartial(length = nil)
        stream!
        @client.readpartial(length)
      end

      # Iterate over the body, allowing it to be enumerable
      def each
        while (chunk = readpartial)
          yield chunk
        end
      end

      # Eagerly consume the entire body as a string
      def to_s
        return @contents if @contents
        fail StateError, 'body is being streamed' unless @streaming.nil?

        begin
          @streaming = false
          @contents = ''
          while (chunk = @client.readpartial)
            @contents << chunk
          end
        rescue
          @contents = nil
          raise
        end

        @contents
      end
      alias_method :to_str, :to_s

      # Assert that the body is actively being streamed
      def stream!
        fail StateError, 'body has already been consumed' if @streaming == false
        @streaming = true
      end

      # Easier to interpret string inspect
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
      end
    end
  end
end
