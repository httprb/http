module HTTP
  class Response
    # A Body class that wraps an IO, rather than a the client
    # object.
    class IoBody
      include Enumerable
      extend Forwardable

      # @return [String,nil] the next `size` octets part of the
      # body, or nil if whole body has already been read.
      def readpartial(size = HTTP::Client::BUFFER_SIZE)
        stream!
        return nil if stream.eof?

        stream.readpartial(size)
      end

      # Iterate over the body, allowing it to be enumerable
      def each
        while part = readpartial # rubocop:disable Lint/AssignmentInCondition
          yield part
        end
      end

      # @return [String] eagerly consume the entire body as a string
      def to_s
        @contents ||= readall
      end
      alias_method :to_str, :to_s

      def_delegator :to_s, :empty?

      # Assert that the body is actively being streamed
      def stream!
        fail StateError, "body has already been consumed" if @streaming == false
        @streaming = true
      end

      # Easier to interpret string inspect
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
      end

      protected

      def initialize(an_io)
        @streaming = nil
        @stream = an_io
      end

      attr_reader :contents, :stream

      def readall
        fail StateError, "body is being streamed" unless @streaming.nil?

        @streaming = false
        String.new.tap do |buf|
          buf << stream.read until stream.eof?
        end
      end
    end
  end
end
