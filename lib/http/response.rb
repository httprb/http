require 'delegate'
require 'http/headers'
require 'http/content_type'
require 'http/mime_type'

module HTTP
  class Response
    include HTTP::Headers::Mixin

    STATUS_CODES = {
      100 => 'Continue',
      101 => 'Switching Protocols',
      102 => 'Processing',
      200 => 'OK',
      201 => 'Created',
      202 => 'Accepted',
      203 => 'Non-Authoritative Information',
      204 => 'No Content',
      205 => 'Reset Content',
      206 => 'Partial Content',
      207 => 'Multi-Status',
      226 => 'IM Used',
      300 => 'Multiple Choices',
      301 => 'Moved Permanently',
      302 => 'Found',
      303 => 'See Other',
      304 => 'Not Modified',
      305 => 'Use Proxy',
      306 => 'Reserved',
      307 => 'Temporary Redirect',
      400 => 'Bad Request',
      401 => 'Unauthorized',
      402 => 'Payment Required',
      403 => 'Forbidden',
      404 => 'Not Found',
      405 => 'Method Not Allowed',
      406 => 'Not Acceptable',
      407 => 'Proxy Authentication Required',
      408 => 'Request Timeout',
      409 => 'Conflict',
      410 => 'Gone',
      411 => 'Length Required',
      412 => 'Precondition Failed',
      413 => 'Request Entity Too Large',
      414 => 'Request-URI Too Long',
      415 => 'Unsupported Media Type',
      416 => 'Requested Range Not Satisfiable',
      417 => 'Expectation Failed',
      418 => "I'm a Teapot",
      422 => 'Unprocessable Entity',
      423 => 'Locked',
      424 => 'Failed Dependency',
      426 => 'Upgrade Required',
      500 => 'Internal Server Error',
      501 => 'Not Implemented',
      502 => 'Bad Gateway',
      503 => 'Service Unavailable',
      504 => 'Gateway Timeout',
      505 => 'HTTP Version Not Supported',
      506 => 'Variant Also Negotiates',
      507 => 'Insufficient Storage',
      510 => 'Not Extended'
    }
    STATUS_CODES.freeze

    SYMBOL_TO_STATUS_CODE = Hash[STATUS_CODES.map { |code, msg| [msg.downcase.gsub(/\s|-/, '_').to_sym, code] }]
    SYMBOL_TO_STATUS_CODE.freeze

    attr_reader :status
    attr_reader :body
    attr_reader :uri

    # Status aliases! TIMTOWTDI!!! (Want to be idiomatic? Just use status :)
    alias_method :code,        :status
    alias_method :status_code, :status

    def initialize(status, version, headers, body, uri = nil) # rubocop:disable ParameterLists
      @status, @version, @body, @uri = status, version, body, uri
      @headers = HTTP::Headers.coerce(headers || {})
    end

    # Obtain the 'Reason-Phrase' for the response
    def reason
      STATUS_CODES[@status]
    end

    # Returns an Array ala Rack: `[status, headers, body]`
    def to_a
      [status, headers.to_h, body.to_s]
    end

    # Return the response body as a string
    def to_s
      body.to_s
    end
    alias_method :to_str, :to_s

    # Flushes body and returns self-reference
    def flush
      body.to_s
      self
    end

    # Parsed Content-Type header
    # @return [HTTP::ContentType]
    def content_type
      @content_type ||= ContentType.parse headers['Content-Type']
    end

    # MIME type of response (if any)
    # @return [String, nil]
    def mime_type
      @mime_type ||= content_type.mime_type
    end

    # Charset of response (if any)
    # @return [String, nil]
    def charset
      @charset ||= content_type.charset
    end

    # Parse response body with corresponding MIME type adapter.
    #
    # @param [#to_s] as Parse as given MIME type
    #   instead of the one determined from headers
    # @raise [Error] if adapter not found
    # @return [Object]
    def parse(as = nil)
      MimeType[as || mime_type].decode to_s
    end

    # Inspect a response
    def inspect
      "#<#{self.class}/#{@version} #{status} #{reason} headers=#{headers.inspect}>"
    end
  end
end
