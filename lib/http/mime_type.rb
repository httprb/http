# frozen_string_literal: true

require "http/errors"

module HTTP
  # MIME type encode/decode adapters
  module MimeType
    class << self
      # Associate MIME type with adapter
      #
      # @example
      #
      #   module JsonAdapter
      #     class << self
      #       def encode(obj)
      #         # encode logic here
      #       end
      #
      #       def decode(str)
      #         # decode logic here
      #       end
      #     end
      #   end
      #
      #   HTTP::MimeType.register_adapter 'application/json', MyJsonAdapter
      #
      # @param [#to_s] type
      # @param [#encode, #decode] adapter
      # @api public
      # @return [void]
      def register_adapter(type, adapter)
        adapters[type.to_s] = adapter
      end

      # Returns adapter associated with MIME type
      #
      # @example
      #   HTTP::MimeType["application/json"]
      #
      # @param [#to_s] type
      # @raise [Error] if no adapter found
      # @api public
      # @return [Class]
      def [](type)
        adapters[normalize type] || raise(UnsupportedMimeTypeError, "Unknown MIME type: #{type}")
      end

      # Register a shortcut for MIME type
      #
      # @example
      #
      #   HTTP::MimeType.register_alias 'application/json', :json
      #
      # @param [#to_s] type
      # @param [#to_sym] shortcut
      # @api public
      # @return [void]
      def register_alias(type, shortcut)
        aliases[shortcut.to_sym] = type.to_s
      end

      # Resolves type by shortcut if possible
      #
      # @example
      #   HTTP::MimeType.normalize(:json)
      #
      # @param [#to_s] type
      # @api public
      # @return [String]
      def normalize(type)
        aliases.fetch type, type.to_s
      end

      private

      # Returns the adapters registry hash
      #
      # @api private
      # @return [Hash]
      def adapters
        @adapters ||= {}
      end

      # Returns the aliases registry hash
      #
      # @api private
      # @return [Hash]
      def aliases
        @aliases ||= {}
      end
    end
  end
end

# built-in mime types
require "http/mime_type/json"
