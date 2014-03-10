module HTTP
  # MIME type encode/decode adapters
  module MimeType
    class << self
      # Associate MIME type with adapter
      #
      # @param [#to_s] type
      # @param [#encode, #decode] adapter
      # @return [void]
      def register_adapter(type, adapter)
        adapters[type.to_s] = adapter
      end

      # Returns adapter associated with MIME type
      #
      # @param [#to_s] type
      # @raise [Error] if no adapter found
      # @return [void]
      def [](type)
        adapters[type.to_s] || fail(Error, "Unknown MIME type: #{type}")
      end

    private

      # :noop:
      def adapters
        @adapters ||= {}
      end
    end
  end
end

# built-in mime types
require 'http/mime_type/json'
