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
      end

      # Read and inflate a chunk of the response body
      #
      # @example
      #   inflater.readpartial # => "decompressed data"
      #
      # @return [String]
      # @raise [EOFError] when no more data left
      # @api public
      def readpartial(*)
        chunk = @connection.readpartial(*)
        zstream.inflate(chunk)
      rescue EOFError
        unless zstream.closed?
          zstream.finish if zstream.total_in.positive?
          zstream.close
        end

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
