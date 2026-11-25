# frozen_string_literal: true

require "zlib"

module HTTP
  class Response
    # Decompresses gzip/deflate response body streams
    class Inflater
      # Largest slice of compressed input handed to zlib at once
      #
      # Deflate can expand input by roughly 1032:1 at most, so a 4 KiB
      # slice caps each decompressed chunk at about 4 MiB, however much
      # compressed data a single read from the connection returns. Each
      # slice is a call to zlib, which has a fixed cost, so smaller slices
      # inflate a large body noticeably slower.
      INPUT_SLICE_SIZE = 4_096
      private_constant :INPUT_SLICE_SIZE

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
        @input      = ""
        @offset     = 0
      end

      # Read and inflate a chunk of the response body
      #
      # Compressed input is inflated one slice at a time, so each call
      # returns a bounded amount of decompressed data even when the
      # compression ratio is extreme. Input left over from an earlier
      # read is consumed before the connection is read again.
      #
      # @example
      #   inflater.readpartial # => "decompressed data"
      #
      # @return [String]
      # @raise [EOFError] when no more data left
      # @api public
      def readpartial(*)
        loop do
          fill_input(*) if @offset >= @input.bytesize
          output = zstream.inflate(next_slice)
          return output unless output.empty?
        end
      rescue EOFError
        close_zstream
        raise
      end

      private

      # Flush and close the zlib stream once the connection is exhausted
      # @return [void]
      # @api private
      def close_zstream
        return if zstream.closed?

        zstream.finished? ? zstream.finish : zstream.reset
        zstream.close
      end

      # Replace the consumed input with a fresh read from the connection
      #
      # A read into a caller-supplied outbuf is copied, because the caller
      # may reuse the outbuf while part of its input is still pending.
      # Without one, the connection returns a new string, which is kept
      # as it is.
      #
      # @return [void]
      # @api private
      def fill_input(*args)
        chunk   = @connection.readpartial(*args)
        @input  = args[1] ? chunk.b : chunk
        @offset = 0
      end

      # Take the next slice of pending compressed input
      #
      # A read that fits in one slice is used whole, without slicing it.
      #
      # @return [String]
      # @api private
      def next_slice
        slice = if @offset.zero? && @input.bytesize <= INPUT_SLICE_SIZE
                  @input
                else
                  String(@input.byteslice(@offset, INPUT_SLICE_SIZE))
                end
        @offset += INPUT_SLICE_SIZE
        slice
      end

      # Return the zlib inflate stream
      # @return [Zlib::Inflate]
      # @api private
      def zstream
        @zstream ||= Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
      end
    end
  end
end
