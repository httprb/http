module HTTP
  module MimeType
    class << self
      def register_adapter(content_type, adapter)
        adapters[content_type.to_s] = adapter
      end

      def [](content_type)
        adapter = adapters[content_type.to_s]
        fail Error, "Unknown MIME type: #{content_type.inspect}" unless adapter
        adapter
      end

    private

      def adapters
        @adapters ||= {}
      end
    end
  end
end

# built-in mime types
require 'http/mime_type/json'
