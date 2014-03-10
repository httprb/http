require 'json'
require 'http/mime_type/adapter'

module HTTP
  module MimeType
    class JSON < Adapter
      def encode(obj)
        return obj.to_json if obj.respond_to?(:to_json)
        ::JSON.dump obj
      end

      def decode(str)
        ::JSON.load str
      end
    end

    register_adapter 'application/json', JSON
  end
end
