# frozen_string_literal: true

require "forwardable"

require "http/errors"
require "http/headers"
require "http/content_type"
require "http/mime_type"
require "http/response/status"
require "http/response/inflater"
require "http/cookie"
require "time"

module HTTP
  # Represents an HTTP response with status, headers, and body
  class Response
    extend Forwardable

    # The response status
    #
    # @example
    #   response.status # => #<HTTP::Response::Status 200>
    #
    # @return [Status] the response status
    # @api public
    attr_reader :status

    # The HTTP version
    #
    # @example
    #   response.version # => "1.1"
    #
    # @return [String] the HTTP version
    # @api public
    attr_reader :version

    # The response body
    #
    # @example
    #   response.body
    #
    # @return [Body] the response body
    # @api public
    attr_reader :body

    # The original request
    #
    # @example
    #   response.request
    #
    # @return [Request] the original request
    # @api public
    attr_reader :request

    # The HTTP headers collection
    #
    # @example
    #   response.headers
    #
    # @return [HTTP::Headers] the response headers
    # @api public
    attr_reader :headers

    # The proxy headers
    #
    # @example
    #   response.proxy_headers
    #
    # @return [Hash] the proxy headers
    # @api public
    attr_reader :proxy_headers

    # Create a new Response instance
    #
    # @example
    #   Response.new(status: 200, version: "1.1", request: req)
    #
    # @param [Integer] status Status code
    # @param [String] version HTTP version
    # @param [Hash] headers
    # @param [Hash] proxy_headers
    # @param [HTTP::Connection, nil] connection
    # @param [String, nil] encoding Encoding to use when reading body
    # @param [String, nil] body
    # @param [HTTP::Request, nil] request The request this is in response to
    # @param [String, nil] uri (DEPRECATED) used to populate a missing request
    # @return [Response]
    # @api public
    def initialize(status:, version:, headers: {}, proxy_headers: {}, connection: nil,
                   encoding: nil, body: nil, request: nil, uri: nil)
      @version       = version
      @request       = init_request(request, uri)
      @status        = HTTP::Response::Status.new(status)
      @headers       = HTTP::Headers.coerce(headers)
      @proxy_headers = HTTP::Headers.coerce(proxy_headers)
      @body          = init_body(body, connection, encoding)
    end

    # @!method reason
    #   Return the reason phrase for the response status
    #   @example
    #     response.reason # => "OK"
    #   @return [String, nil]
    #   @api public
    def_delegator :@status, :reason

    # @!method code
    #   Return the numeric status code
    #   @example
    #     response.code # => 200
    #   @return [Integer]
    #   @api public
    def_delegator :@status, :code

    # @!method to_s
    #   Consume the response body as a string
    #   @example
    #     response.to_s # => "<html>...</html>"
    #   @return [String]
    #   @api public
    def_delegator :@body, :to_s
    alias to_str to_s

    # @!method readpartial
    #   Read a chunk of the response body
    #   @example
    #     response.readpartial # => "chunk"
    #   @return [String]
    #   @raise [EOFError] when no more data left
    #   @api public
    def_delegator :@body, :readpartial

    # @!method connection
    #   Return the underlying connection object
    #   @example
    #     response.connection
    #   @return [HTTP::Connection]
    #   @api public
    def_delegator :@body, :connection

    # @!method uri
    #   Return the URI of the original request
    #   @example
    #     response.uri # => #<HTTP::URI ...>
    #   @return (see HTTP::Request#uri)
    #   @api public
    def_delegator :@request, :uri

    # Returns an Array ala Rack: `[status, headers, body]`
    #
    # @example
    #   response.to_a # => [200, {"Content-Type" => "text/html"}, "body"]
    #
    # @return [Array(Fixnum, Hash, String)]
    # @api public
    def to_a
      [status.to_i, headers.to_h, body.to_s]
    end

    # @!method deconstruct
    #   Array pattern matching interface
    #
    #   @example
    #     response.deconstruct
    #
    #   @see #to_a
    #   @return [Array(Integer, Hash, String)]
    #   @api public
    alias deconstruct to_a

    # Pattern matching interface for matching against response attributes
    #
    # @example
    #   case response
    #   in { status: 200..299, body: /success/ }
    #     "ok"
    #   in { status: 400.. }
    #     "error"
    #   end
    #
    # @param keys [Array<Symbol>, nil] keys to extract, or nil for all
    # @return [Hash{Symbol => Object}]
    # @api public
    def deconstruct_keys(keys)
      hash = {
        status:        @status,
        version:       @version,
        headers:       @headers,
        body:          @body,
        request:       @request,
        proxy_headers: @proxy_headers
      }
      keys ? hash.slice(*keys) : hash
    end

    # Flushes body and returns self-reference
    #
    # @example
    #   response.flush # => #<HTTP::Response ...>
    #
    # @return [Response]
    # @api public
    def flush
      body.to_s
      self
    end

    # Value of the Content-Length header
    #
    # @example
    #   response.content_length # => 438
    #
    # @return [nil] if Content-Length was not given, or it's value was invalid
    #   (not an integer, e.g. empty string or string with non-digits).
    # @return [Integer] otherwise
    # @api public
    def content_length
      # http://greenbytes.de/tech/webdav/rfc7230.html#rfc.section.3.3.3
      # Clause 3: "If a message is received with both a Transfer-Encoding
      # and a Content-Length header field, the Transfer-Encoding overrides the Content-Length.
      return nil if @headers.include?(Headers::TRANSFER_ENCODING)

      value = @headers[Headers::CONTENT_LENGTH]
      return nil unless value

      Integer(value, exception: false)
    end

    # Parsed Content-Type header
    #
    # @example
    #   response.content_type # => #<HTTP::ContentType ...>
    #
    # @return [HTTP::ContentType]
    # @api public
    def content_type
      @content_type ||= ContentType.parse headers[Headers::CONTENT_TYPE]
    end

    # @!method mime_type
    #   MIME type of response (if any)
    #   @example
    #     response.mime_type # => "text/html"
    #   @return [String, nil]
    #   @api public
    def_delegator :content_type, :mime_type

    # @!method charset
    #   Charset of response (if any)
    #   @example
    #     response.charset # => "utf-8"
    #   @return [String, nil]
    #   @api public
    def_delegator :content_type, :charset

    # Cookies from Set-Cookie headers
    #
    # @example
    #   response.cookies # => [#<HTTP::Cookie ...>, ...]
    #
    # @return [Array<HTTP::Cookie>]
    # @api public
    def cookies
      @cookies ||= headers.get(Headers::SET_COOKIE).flat_map { |v| HTTP::Cookie.parse(v, uri) }
    end

    # Check if the response uses chunked transfer encoding
    #
    # @example
    #   response.chunked? # => true
    #
    # @return [Boolean]
    # @api public
    def chunked?
      return false unless @headers.include?(Headers::TRANSFER_ENCODING)

      encoding = @headers.get(Headers::TRANSFER_ENCODING)

      # TODO: "chunked" is frozen in the request writer. How about making it accessible?
      encoding.last == "chunked"
    end

    # Parse response body with corresponding MIME type adapter
    #
    # @example
    #   response.parse("application/json") # => {"key" => "value"}
    #
    # @param type [#to_s] Parse as given MIME type.
    # @raise (see MimeType.[])
    # @return [Object]
    # @api public
    def parse(type = nil)
      MimeType[type || mime_type].decode to_s
    rescue => e
      raise ParseError, e.message
    end

    # Inspect a response
    #
    # @example
    #   response.inspect # => "#<HTTP::Response/1.1 200 OK text/html>"
    #
    # @return [String]
    # @api public
    def inspect
      "#<#{self.class}/#{@version} #{code} #{reason} #{mime_type}>"
    end

    private

    # Determine the default encoding for the body
    # @return [Encoding]
    # @api private
    def default_encoding
      return Encoding::UTF_8 if mime_type == "application/json"

      Encoding::BINARY
    end

    # Initialize the response body
    #
    # @return [Body]
    # @api private
    def init_body(body, connection, encoding)
      if body
        body
      else
        encoding ||= charset || default_encoding

        Response::Body.new(connection, encoding: encoding)
      end
    end

    # Initialize an HTTP::Request
    #
    # @return [HTTP::Request]
    # @api private
    def init_request(request, uri)
      raise ArgumentError, ":uri is for backwards compatibilty and conflicts with :request" if request && uri

      # For backwards compatibilty
      if uri
        HTTP::Request.new(uri: uri, verb: :get)
      else
        request
      end
    end
  end
end
