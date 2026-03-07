# frozen_string_literal: true

require "forwardable"
require "singleton"

module HTTP
  module MimeType
    # Base encode/decode MIME type adapter
    class Adapter
      include Singleton

      class << self
        extend Forwardable

        def_delegators :instance, :encode, :decode # steep:ignore
      end

      # Encodes data into the MIME type format
      #
      # @example
      #   adapter.encode("foo" => "bar")
      #
      # @return [String] encoded representation
      # @raise [Error] if not implemented by subclass
      # @api public
      def encode(*)
        raise Error, "#{self.class} does not supports #encode"
      end

      # Decodes data from the MIME type format
      #
      # @example
      #   adapter.decode("{\"foo\":\"bar\"}")
      #
      # @return [Object] decoded data
      # @raise [Error] if not implemented by subclass
      # @api public
      def decode(*)
        raise Error, "#{self.class} does not supports #decode"
      end
    end
  end
end
