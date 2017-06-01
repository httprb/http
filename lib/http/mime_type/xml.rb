require "http/mime_type/adapter"

module HTTP
  module MimeType
    class XML < Adapter
      def decode(str)
        require "nokogiri"
        Nokogiri::XML(str)
      rescue LoadError
        raise "Please install nokogiri to parse XML responses"
      end
    end

    register_adapter "text/xml", XML
    register_adapter "application/xml", XML
  end
end
