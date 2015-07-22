require "forwardable"

require "http/headers"
require "http/content_type"
require "http/mime_type"
require "http/response/status"
require "http/uri"
require "http/cookie_jar"
require "time"

module HTTP
  class Response
    extend Forwardable

    include HTTP::Headers::Mixin

    # @deprecated Will be removed in 1.0.0
    #   Use Status::REASONS
    STATUS_CODES = Status::REASONS

    # @deprecated Will be removed in 1.0.0
    SYMBOL_TO_STATUS_CODE = Hash[STATUS_CODES.map { |k, v| [v.downcase.gsub(/\s|-/, "_").to_sym, k] }].freeze

    # @return [Status]
    attr_reader :status

    # @return [Body]
    attr_reader :body

    # @return [URI, nil]
    attr_reader :uri

    def initialize(status, version, headers, body, uri = nil) # rubocop:disable ParameterLists
      @version = version
      @body    = body
      @uri     = uri && HTTP::URI.parse(uri)
      @status  = HTTP::Response::Status.new status
      @headers = HTTP::Headers.coerce(headers || {})
    end

    # @!method reason
    #   @return (see HTTP::Response::Status#reason)
    def_delegator :status, :reason

    # @!method code
    #   @return (see HTTP::Response::Status#code)
    def_delegator :status, :code

    # @deprecated Will be removed in 1.0.0
    alias_method :status_code, :code

    # @!method to_s
    #   (see HTTP::Response::Body#to_s)
    def_delegator :body, :to_s
    alias_method :to_str, :to_s

    # @!method readpartial
    #   (see HTTP::Response::Body#readpartial)
    def_delegator :body, :readpartial

    # Returns an Array ala Rack: `[status, headers, body]`
    #
    # @return [Array(Fixnum, Hash, String)]
    def to_a
      [status.to_i, headers.to_h, body.to_s]
    end

    # Flushes body and returns self-reference
    #
    # @return [Response]
    def flush
      body.to_s
      self
    end

    # Parsed Content-Type header
    #
    # @return [HTTP::ContentType]
    def content_type
      @content_type ||= ContentType.parse headers[Headers::CONTENT_TYPE]
    end

    # MIME type of response (if any)
    #
    # @return [String, nil]
    def mime_type
      @mime_type ||= content_type.mime_type
    end

    # Charset of response (if any)
    #
    # @return [String, nil]
    def charset
      @charset ||= content_type.charset
    end

    def cookies
      @cookies ||= headers.each_with_object CookieJar.new do |(k, v), jar|
        jar.parse(v, uri) if k == Headers::SET_COOKIE
      end
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
      "#<#{self.class}/#{@version} #{code} #{reason} #{headers.to_h.inspect}>"
    end
  end
end
