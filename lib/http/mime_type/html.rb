require "http/mime_type/adapter"

module HTTP
  module MimeType
    class HTML < Adapter
      def decode(str)
        begin
          require 'nokogiri'
          Nokogiri::HTML(str)
        rescue LoadError
          raise "Please install nokogiri to parse HTML responses"
        end
      end
    end

    register_adapter "text/html", HTML
  end
end