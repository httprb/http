require 'nokogiri'
require "http/mime_type/adapter"

module HTTP
  module MimeType
    class HTML < Adapter
      def decode(str)
				Nokogiri::HTML(str)
      end
    end

    register_adapter "text/html", HTML
  end
end
