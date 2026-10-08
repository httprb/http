# frozen_string_literal: true

require "stringio"

module HTTP
  module FormData
    # Provides IO interface across multiple IO objects.
    class CompositeIO
      # Creates a new CompositeIO from an array of IOs
      #
      # @example
      #   CompositeIO.new([StringIO.new("hello"), StringIO.new(" world")])
      #
      # @api public
      # @param [Array<IO>] ios Array of IO objects
      def initialize(ios)
        @index = 0
        @ios   = ios.map do |io|
          if io.is_a?(String)
            StringIO.new(io)
          elsif io.respond_to?(:read)
            io
          else
            raise ArgumentError,
                  "#{io.inspect} is neither a String nor an IO object"
          end
        end
      end

      # Reads and returns content across multiple IO objects
      #
      # @example
      #   composite_io.read     # => "hello world"
      #   composite_io.read(5)  # => "hello"
      #
      # @api public
      # @param [Integer] length Number of bytes to retrieve
      # @param [String] outbuf String to be replaced with retrieved data
      # @return [String, nil]
      def read(length = nil, outbuf = nil)
        data   = outbuf.clear.force_encoding(Encoding::BINARY) if outbuf
        data ||= "".b

        read_chunks(length) { |chunk| data << chunk }

        data unless length && data.empty?
      end

      # Returns sum of all IO sizes
      #
      # @example
      #   composite_io.size # => 11
      #
      # @api public
      # @return [Integer]
      def size
        @size ||= @ios.sum(&:size)
      end

      # Rewinds all IO objects and resets cursor
      #
      # @example
      #   composite_io.rewind
      #
      # @api public
      # @return [void]
      def rewind
        @ios.each(&:rewind)
        @index = 0
      end

      private

      # Yields chunks with total length up to `length`
      #
      # @api private
      # @return [void]
      def read_chunks(length)
        while (chunk = readpartial(length))
          yield chunk.force_encoding(Encoding::BINARY)

          next if length.nil?

          remaining = length - chunk.bytesize
          break if remaining.zero?

          length = remaining
        end
      end

      # Reads chunk from current IO with length up to `max_length`
      #
      # @api private
      # @return [String, nil]
      def readpartial(max_length)
        while (io = @ios.at(@index))
          chunk = io.read(max_length)

          return chunk if chunk && !chunk.empty?

          @index += 1
        end
      end
    end
  end
end
