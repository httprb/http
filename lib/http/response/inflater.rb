# frozen_string_literal: true

require "zlib"

module HTTP
  class Response
    # Decompresses gzip/deflate response body streams
    class Inflater
      # The underlying connection
      #
      # @example
      #   inflater.connection
      #
      # @return [HTTP::Connection] the underlying connection
      # @api public
      attr_reader :connection

      # Create a new Inflater wrapping a connection
      #
      # @example
      #   Inflater.new(connection)
      #
      # @param connection [HTTP::Connection] the connection to inflate
      # @return [Inflater]
      # @api public
      def initialize(connection)
        @connection = connection
        @buffer = String.new(encoding: Encoding::BINARY)
      end

      # Read and inflate a chunk of the response body
      #
      # @example
      #   inflater.readpartial # => "decompressed data"
      #
      # @param size [Integer, *] maximum number of bytes to return
      # @return [String]
      # @raise [EOFError] when no more data left
      # @api public
      def readpartial(size = nil, *)
        loop do
          return @buffer.slice!(0, size || @buffer.bytesize) unless @buffer.empty?

          chunk = size ? @connection.readpartial(size, *) : @connection.readpartial(*)
          raise EOFError if chunk.nil? || chunk.empty?

          inflated = zstream.inflate(chunk)
          next if inflated.empty?
          return inflated unless size && inflated.bytesize > size

          @buffer << inflated
        end
      rescue EOFError
        unless zstream.closed?
          zstream.finished? ? zstream.finish : zstream.reset
          zstream.close
        end

        return @buffer.slice!(0, size || @buffer.bytesize) unless @buffer.empty?

        raise
      end

      private

      # Return the zlib inflate stream
      # @return [Zlib::Inflate]
      # @api private
      def zstream
        @zstream ||= Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
      end
    end
  end
end
