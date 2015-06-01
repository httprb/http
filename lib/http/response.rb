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

    # @return [Status]
    attr_reader :status

    # @return [Body]
    attr_reader :body

    # @return [URI, nil]
    attr_reader :uri

    # Inits a new instance
    #
    # @option opts [Integer] :status Status code
    # @option opts [String] :version HTTP version
    # @option opts [Hash] :headers
    # @option opts [HTTP::Connection] :connection
    # @option opts [String] :encoding Encoding to use when reading body
    # @option opts [String] :body
    # @option opts [String] :uri
    def initialize(opts)
      @version  = opts.fetch(:version)
      @uri      = opts.include?(:uri) && HTTP::URI.parse(opts.fetch(:uri))
      @status   = HTTP::Response::Status.new opts.fetch(:status)
      @headers  = HTTP::Headers.coerce(opts.fetch(:headers, {}))
      @encoding = opts.fetch(:encoding, nil)

      if opts.include?(:connection)
        @body = Response::Body.new(opts.fetch(:connection), resolved_encoding)
      else
        @body = opts.fetch(:body)
      end
    end

    # @!method reason
    #   @return (see HTTP::Response::Status#reason)
    def_delegator :status, :reason

    # @!method code
    #   @return (see HTTP::Response::Status#code)
    def_delegator :status, :code

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

    private

    # Work out what encoding to assume for the body
    def resolved_encoding
      @encoding || charset || Encoding::BINARY
    end
  end
end
