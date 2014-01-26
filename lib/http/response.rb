require 'delegate'
require 'http/header'
require 'http/content_type'

module HTTP
  class Response
    include HTTP::Header

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
    attr_reader :headers
    attr_reader :body
    attr_reader :uri

    # Status aliases! TIMTOWTDI!!! (Want to be idiomatic? Just use status :)
    alias_method :code,        :status
    alias_method :status_code, :status

    def initialize(connection, status, version, headers, uri = nil) # rubocop:disable ParameterLists
      @connection    = connection
      @status        = status
      @version       = version
      @uri           = uri
      @finished_read = false
      @buffer        = ""
      @body          = Response::Body.new(self)

      @headers = {}
      headers.each { |field, value| self[field] = value }
    end

    # Set a header
    def []=(name, value)
      # If we have a canonical header, we're done
      key = name[CANONICAL_HEADER]

      # Convert to canonical capitalization
      key ||= canonicalize_header(name)

      # Check if the header has already been set and group
      if @headers.key? key
        @headers[key] = Array(@headers[key]) + Array(value)
      else
        @headers[key] = value
      end
    end

    # Obtain the 'Reason-Phrase' for the response
    def reason
      STATUS_CODES[@status]
    end

    # Get a header value
    def [](name)
      @headers[name] || @headers[canonicalize_header(name)]
    end

    # Returns an Array ala Rack: `[status, headers, body]`
    def to_a
      [status, headers, body.to_s]
    end

    # Return the response body as a string
    def to_s
      body.to_s
    end
    alias_method :to_str, :to_s

    # Parsed Content-Type header
    # @return [HTTP::ContentType]
    def content_type
      @content_type ||= ContentType.parse @headers['Content-Type']
    end

    # MIME type of response (if any)
    # @return [String, nil]
    def mime_type
      @mime_type ||= content_type.mime_type
    end

    # Charset of response (if any)
    # @return [String, nil]
    def charset
      @mime_type ||= content_type.charset
    end

    # Returns true if request fully finished reading
    def finished_reading?; @finished_read; end

    # When HTTP Parser marks the message parsing as complete, this will be set.
    def finish_reading!
      raise StateError, "already finished" if @finished_read
      @finished_read = true
    end

    # Fill the request buffer with data as it becomes available
    def fill_buffer(chunk)
      @buffer << chunk
    end

    # Read a number of bytes, looping until they are available or until
    # readpartial returns nil, indicating there are no more bytes to read
    def read(length = nil, buffer = nil)
      raise ArgumentError, "negative length #{length} given" if length && length < 0

      return '' if length == 0
      res = buffer.nil? ? '' : buffer.clear

      chunk_size = length.nil? ? @connection.buffer_size : length
      begin
        while chunk_size > 0
          chunk = readpartial(chunk_size)
          break unless chunk
          res << chunk
          chunk_size = length - res.length unless length.nil?
        end
      rescue EOFError
      end
      return length && res.length == 0 ? nil : res
    end

    # Read a string up to the given number of bytes, blocking until some
    # data is available but returning immediately if some data is available
    def readpartial(length = nil)
      if length.nil? && @buffer.length > 0
        slice = @buffer
        @buffer = ""
      else
        unless finished_reading? || (length && length <= @buffer.length)
          @connection.readpartial(length ? length - @buffer.length : @connection.buffer_size)
        end

        if length
          slice = @buffer.slice!(0, length)
        else
          slice = @buffer
          @buffer = ""
        end
      end

      slice && slice.length == 0 ? nil : slice
    end

    # Inspect a response
    def inspect
      "#<#{self.class}/#{@version} #{status} #{reason} @headers=#{@headers.inspect}>"
    end
  end
end
