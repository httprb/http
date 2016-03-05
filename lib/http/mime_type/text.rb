require "http/mime_type/adapter"

module HTTP
  module MimeType
    class Text < Adapter
      def decode(str)
				str.to_s
      end
    end

    register_adapter "text/plain", Text
  end
end
