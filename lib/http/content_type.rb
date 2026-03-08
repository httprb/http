# frozen_string_literal: true

module HTTP
  # Parsed representation of a Content-Type header
  class ContentType
    # Pattern for extracting MIME type from Content-Type header
    MIME_TYPE_RE = %r{^([^/]+/[^;]+)(?:$|;)}
    # Pattern for extracting charset from Content-Type header
    CHARSET_RE   = /;\s*charset=([^;]+)/i

    # MIME type of the content
    #
    # @example
    #   content_type.mime_type # => "text/html"
    #
    # @return [String, nil]
    # @api public
    attr_accessor :mime_type

    # Character set of the content
    #
    # @example
    #   content_type.charset # => "utf-8"
    #
    # @return [String, nil]
    # @api public
    attr_accessor :charset

    class << self
      # Parse string and return ContentType object
      #
      # @example
      #   HTTP::ContentType.parse("text/html; charset=utf-8")
      #
      # @param [String] str content type header value
      # @return [ContentType]
      # @api public
      def parse(str)
        new mime_type(str), charset(str)
      end

      private

      # Extract MIME type from header string
      # @return [String, nil]
      # @api private
      def mime_type(str)
        str.to_s[MIME_TYPE_RE, 1]&.strip&.downcase
      end

      # Extract charset from header string
      # @return [String, nil]
      # @api private
      def charset(str)
        str.to_s[CHARSET_RE, 1]&.strip&.delete('"')
      end
    end

    # Create a new ContentType instance
    #
    # @example
    #   HTTP::ContentType.new("text/html", "utf-8")
    #
    # @param [String, nil] mime_type MIME type
    # @param [String, nil] charset character set
    # @return [ContentType]
    # @api public
    def initialize(mime_type = nil, charset = nil)
      @mime_type = mime_type
      @charset   = charset
    end
  end
end
