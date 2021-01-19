# frozen_string_literal: true

require "zlib"

module HTTP
  class Response
    class Inflater
      attr_reader :connection

      def initialize(connection)
        @connection = connection
      end

      def readpartial(*args)
        chunk = @connection.readpartial(*args)
        if chunk
          chunk = zstream.inflate(chunk)
        elsif !zstream.closed?
          zstream.finish if zstream.total_in.positive?
          zstream.close
        end
        chunk
      end

      # Hash representation of an inflater
      #
      # @return [Hash[Symbol, Any]]
      def to_h
        {
          connection: connection
        }
      end

      # Pattern matching interface
      #
      # @param keys [Array[Symbol]]
      #   Keys to extract
      #
      # @return [Hash[Symbol, Any]]
      def deconstruct_keys(keys)
        to_h.slice(*keys)
      end

      private

      def zstream
        @zstream ||= Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
      end
    end
  end
end
