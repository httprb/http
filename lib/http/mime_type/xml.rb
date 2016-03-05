require 'nokogiri'
require "http/mime_type/adapter"

module HTTP
  module MimeType
    class XML < Adapter
      def decode(str)
				Nokogiri::XML(str)
      end
    end

    register_adapter "text/xml", XML
    register_adapter "application/xml", XML
  end
end
