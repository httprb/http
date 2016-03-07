require "forwardable"
require "http/client"

module HTTP
  class Response
    # A streamable response body, also easily converted into a string
    class Body
      extend Forwardable
      include Enumerable
      def_delegator :to_s, :empty?

      def initialize(client, encoding = Encoding::BINARY)
        @client    = client
        @streaming = nil
        @contents  = nil
        @encoding  = encoding
      end

      # (see HTTP::Client#readpartial)
      def readpartial(*args)
        stream!
        @client.readpartial(*args)
      end

      # Iterate over the body, allowing it to be enumerable
      def each
        while (chunk = readpartial)
          yield chunk
        end
      end

      # @return [String] eagerly consume the entire body as a string
      def to_s
        return @contents if @contents

        fail StateError, "body is being streamed" unless @streaming.nil?

        # see issue 312
        begin
          encoding = Encoding.find @encoding
        rescue ArgumentError
          encoding = Encoding::BINARY
        end

        begin
          @streaming = false
          @contents = "".force_encoding(encoding)
          while (chunk = @client.readpartial)
            @contents << chunk.force_encoding(encoding)
          end
        rescue
          @contents = nil
          raise
        end

        @contents
      end
      alias to_str to_s

      # Assert that the body is actively being streamed
      def stream!
        fail StateError, "body has already been consumed" if @streaming == false
        @streaming = true
      end

      # Easier to interpret string inspect
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
      end
    end
  end
end
