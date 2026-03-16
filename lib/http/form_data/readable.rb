# frozen_string_literal: true

module HTTP
  module FormData
    # Common behaviour for objects defined by an IO object.
    module Readable
      # Returns IO content as a String
      #
      # @example
      #   readable.to_s # => "content"
      #
      # @api public
      # @return [String]
      def to_s
        rewind
        content = read #: String
        rewind
        content
      end

      # Reads and returns part of IO content
      #
      # @example
      #   readable.read      # => "full content"
      #   readable.read(5)   # => "full "
      #
      # @api public
      # @param [Integer] length Number of bytes to retrieve
      # @param [String] outbuf String to be replaced with retrieved data
      # @return [String, nil]
      def read(length = nil, outbuf = nil)
        @io.read(length, outbuf)
      end

      # Returns IO size in bytes
      #
      # @example
      #   readable.size # => 42
      #
      # @api public
      # @return [Integer]
      def size
        @io.size
      end

      # Rewinds the IO to the beginning
      #
      # @example
      #   readable.rewind
      #
      # @api public
      # @return [void]
      def rewind
        @io.rewind
      end
    end
  end
end
