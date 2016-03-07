module HTTP
  ContentType = Struct.new(:mime_type, :charset) do
    MIME_TYPE_RE = %r{^([^/]+/[^;]+)(?:$|;)}
    CHARSET_RE   = /;\s*charset=([^;]+)/i

    class << self
      # Parse string and return ContentType struct
      def parse(str)
        new mime_type(str), charset(str)
      end

      private

      # :nodoc:
      def mime_type(str)
        md = str.to_s.match MIME_TYPE_RE
        md && md[1].to_s.strip.downcase
      end

      # :nodoc:
      def charset(str)
        md = str.to_s.match CHARSET_RE
        md && md[1].to_s.strip.gsub(/^"|"$/, "")
      end
    end
  end
end
