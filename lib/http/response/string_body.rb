module HTTP
  class Response
    # A Body class that wraps a String, rather than a the client
    # object.
    class StringBody
      include Enumerable
      extend Forwardable

      # @return [String,nil] the next `size` octets part of the
      # body, or nil if whole body has already been read.
      def readpartial(size = @contents.length)
        stream!
        return nil if @streaming_offset >= @contents.length

        @contents[@streaming_offset, size].tap do |part|
          @streaming_offset += (part.length + 1)
        end
      end

      # Iterate over the body, allowing it to be enumerable
      def each
        yield @contents
      end

      # @return [String] eagerly consume the entire body as a string
      def to_s
        @contents
      end
      alias_method :to_str, :to_s

      def_delegator :@contents, :empty?

      # Assert that the body is actively being streamed
      def stream!
        fail StateError, "body has already been consumed" if @streaming == false
        @streaming = true
      end

      # Easier to interpret string inspect
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)}>"
      end

      protected

      def initialize(contents)
        @contents = contents
        @streaming = nil
        @streaming_offset = 0
      end
    end
  end
end
