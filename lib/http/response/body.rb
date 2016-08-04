# frozen_string_literal: true
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

        # see issue 312
        begin
          @encoding = Encoding.find encoding
        rescue ArgumentError
          @encoding = Encoding::BINARY
        end
      end

      # (see HTTP::Client#readpartial)
      def readpartial(*args)
        stream!
        force_encoding @client.readpartial(*args)
      end

      # Iterate over the body, allowing it to be enumerable
      def each
        return to_enum __method__ unless block_given?

        while (chunk = readpartial)
          yield chunk
        end

        self
      end

      # @return [String] eagerly consume the entire body as a string
      def to_s
        return @contents if @contents

        raise StateError, "body is being streamed" unless @streaming.nil?

        begin
          @streaming  = false
          @contents   = force_encoding(String.new(""))

          while (chunk = @client.readpartial)
            @contents << force_encoding(chunk)
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
        raise StateError, "body has already been consumed" if @streaming == false
        @streaming = true
      end

      # Easier to interpret string inspect
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
      end

      private

      def force_encoding(chunk)
        chunk && chunk.force_encoding(@encoding)
      end
    end
  end
end
