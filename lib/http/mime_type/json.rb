# frozen_string_literal: true

require "json"
require "http/mime_type/adapter"

module HTTP
  module MimeType
    # JSON encode/decode MIME type adapter
    class JSON < Adapter
      # Encodes object to JSON
      #
      # @example
      #   adapter = HTTP::MimeType::JSON.new
      #   adapter.encode(foo: "bar")
      #
      # @param [Object] obj object to encode
      # @api public
      # @return [String]
      def encode(obj)
        return obj.to_json if obj.respond_to?(:to_json)

        ::JSON.dump obj
      end

      # Decodes JSON string into Ruby object
      #
      # @example
      #   adapter = HTTP::MimeType::JSON.new
      #   adapter.decode('{"foo":"bar"}')
      #
      # @param [String] str JSON string to decode
      # @api public
      # @return [Object]
      def decode(str)
        ::JSON.parse str
      end
    end

    register_adapter "application/json", JSON
    register_alias   "application/json", :json
  end
end
