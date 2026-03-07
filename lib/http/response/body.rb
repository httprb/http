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

      # The connection object for the request
      #
      # @example
      #   body.connection
      #
      # @return [HTTP::Connection]
      # @api public
      attr_reader :connection

      # Create a new Body instance
      #
      # @example
      #   Body.new(stream, encoding: Encoding::UTF_8)
      #
      # @param stream [#readpartial] the response stream
      # @param encoding [Encoding] the encoding to use
      # @return [Body]
      # @api public
      def initialize(stream, encoding: Encoding::BINARY)
        @stream     = stream
        @connection = stream.is_a?(Inflater) ? stream.connection : stream
        @streaming  = nil
        @contents   = nil
        @encoding   = find_encoding(encoding)
      end

      # Read a chunk of the body
      #
      # @example
      #   body.readpartial # => "chunk of data"
      #
      # (see HTTP::Client#readpartial)
      # @return [String, nil]
      # @api public
      def readpartial(*args)
        stream!
        chunk = @stream.readpartial(*args)

        String.new(chunk, encoding: @encoding) if chunk
      end

      # Iterate over the body, allowing it to be enumerable
      #
      # @example
      #   body.each { |chunk| puts chunk }
      #
      # @yield [chunk] Passes each chunk to the block
      # @yieldparam chunk [String]
      # @return [void]
      # @api public
      def each
        while (chunk = readpartial)
          yield chunk
        end
      end

      # Eagerly consume the entire body as a string
      #
      # @example
      #   body.to_s # => "full response body"
      #
      # @return [String]
      # @api public
      def to_s
        return @contents if @contents

        raise StateError, "body is being streamed" unless @streaming.nil?

        begin
          @streaming = false
          @contents = read_contents
        rescue
          @contents = nil
          raise
        end

        @contents
      end
      alias to_str to_s

      # Assert that the body is actively being streamed
      #
      # @example
      #   body.stream!
      #
      # @return [true]
      # @api public
      def stream!
        raise StateError, "body has already been consumed" if @streaming == false

        @streaming = true
      end

      # Easier to interpret string inspect
      #
      # @example
      #   body.inspect # => "#<HTTP::Response::Body:3ff2 @streaming=false>"
      #
      # @return [String]
      # @api public
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
      end

      private

      # Read all chunks into a single string
      #
      # @return [String]
      # @api private
      def read_contents
        contents = String.new("", encoding: @encoding)

        while (chunk = @stream.readpartial)
          contents << String.new(chunk, encoding: @encoding)
          chunk = nil # deallocate string
        end

        contents
      end

      # Retrieve encoding by name
      #
      # @return [Encoding]
      # @api private
      def find_encoding(encoding)
        Encoding.find encoding
      rescue ArgumentError
        Encoding::BINARY
      end
    end
  end
end
