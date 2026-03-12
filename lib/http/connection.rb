# frozen_string_literal: true

require "forwardable"

require "http/connection/internals"
require "http/headers"

module HTTP
  # A connection to the HTTP server
  class Connection
    extend Forwardable
    include Internals

    # Allowed values for CONNECTION header
    KEEP_ALIVE = "Keep-Alive"
    # Connection: close header value
    CLOSE      = "close"

    # Attempt to read this much data
    BUFFER_SIZE = 16_384

    # Maximum response body size (in bytes) to auto-flush when reusing
    # a connection. Bodies larger than this cause the connection to close
    # instead, to avoid blocking on huge downloads.
    MAX_FLUSH_SIZE = 1_048_576

    # HTTP/1.0
    HTTP_1_0 = "1.0"

    # HTTP/1.1
    HTTP_1_1 = "1.1"

    # Returned after HTTP CONNECT (via proxy)
    #
    # @example
    #   connection.proxy_response_headers
    #
    # @return [HTTP::Headers, nil]
    # @api public
    attr_reader :proxy_response_headers

    # Initialize a new connection to an HTTP server
    #
    # @example
    #   Connection.new(req, options)
    #
    # @param [HTTP::Request] req
    # @param [HTTP::Options] options
    # @return [Connection]
    # @raise [HTTP::ConnectionError] when failed to connect
    # @api public
    def initialize(req, options)
      init_state(options)
      connect_socket(req, options)
    rescue IO::TimeoutError => e
      close
      raise ConnectTimeoutError, e.message, e.backtrace
    rescue IOError, SocketError, SystemCallError => e
      raise ConnectionError, "failed to connect: #{e}", e.backtrace
    rescue TimeoutError
      close
      raise
    end

    # @see (HTTP::Response::Parser#status_code)
    def_delegator :@parser, :status_code

    # @see (HTTP::Response::Parser#http_version)
    def_delegator :@parser, :http_version

    # @see (HTTP::Response::Parser#headers)
    def_delegator :@parser, :headers

    # Whether the proxy CONNECT request failed
    #
    # @example
    #   connection.failed_proxy_connect?
    #
    # @return [Boolean] whenever proxy connect failed
    # @api public
    def failed_proxy_connect?
      @failed_proxy_connect
    end

    # Set the pending response for auto-flushing before the next request
    #
    # @example
    #   connection.pending_response = response
    #
    # @param [HTTP::Response, false] response
    # @return [void]
    # @api public
    attr_writer :pending_response

    # Send a request to the server
    #
    # @example
    #   connection.send_request(req)
    #
    # @param [Request] req Request to send to the server
    # @return [nil]
    # @api public
    def send_request(req)
      flush_pending_response if @pending_response

      if @pending_request
        raise StateError, "Tried to send a request while a response is pending. Make sure you read off the body."
      end

      @pending_request = true

      req.stream @socket

      @pending_response = true
      @pending_request  = false
    end

    # Read a chunk of the body
    #
    # @example
    #   connection.readpartial
    #
    # @param [Integer] size maximum bytes to read
    # @param [String, nil] outbuf buffer to fill with data
    # @return [String] data chunk
    # @raise [EOFError] when no more data left
    # @api public
    def readpartial(size = BUFFER_SIZE, outbuf = nil)
      raise EOFError unless @pending_response

      chunk = @parser.read(size)
      unless chunk
        eof = read_more(size) == :eof
        check_premature_eof(eof)
        finished = eof || @parser.finished?
        chunk    = @parser.read(size) || "".b
        finish_response if finished
      end

      outbuf ? outbuf.replace(chunk) : chunk
    end

    # Reads data from socket up until headers are loaded
    #
    # @example
    #   connection.read_headers!
    #
    # @return [void]
    # @raise [ResponseHeaderError] when unable to read response headers
    # @api public
    def read_headers!
      until @parser.headers?
        result = read_more(BUFFER_SIZE)
        raise ResponseHeaderError, "couldn't read response headers" if result == :eof
      end

      set_keep_alive
    end

    # Callback for when we've reached the end of a response
    #
    # @example
    #   connection.finish_response
    #
    # @return [void]
    # @api public
    def finish_response
      close unless keep_alive?

      @parser.reset
      @socket.reset_counter if @socket.respond_to?(:reset_counter)
      reset_timer

      @pending_response = false
    end

    # Close the connection
    #
    # @example
    #   connection.close
    #
    # @return [void]
    # @api public
    def close
      @socket.close unless @socket&.closed?

      @pending_response = false
      @pending_request  = false
    end

    # Whether there are no pending requests or responses
    #
    # @example
    #   connection.finished_request?
    #
    # @return [Boolean]
    # @api public
    def finished_request?
      !@pending_request && !@pending_response
    end

    # Whether we're keeping the conn alive
    #
    # @example
    #   connection.keep_alive?
    #
    # @return [Boolean]
    # @api public
    def keep_alive?
      @keep_alive && !@socket.closed?
    end

    # Whether our connection has expired
    #
    # @example
    #   connection.expired?
    #
    # @return [Boolean]
    # @api public
    def expired?
      !@conn_expires_at || @conn_expires_at < Time.now
    end

    private

    # Initialize connection state
    # @return [void]
    # @api private
    def init_state(options)
      @persistent           = options.persistent?
      @keep_alive_timeout   = options.keep_alive_timeout.to_f
      @pending_request      = false
      @pending_response     = false
      @failed_proxy_connect = false
      @buffer               = "".b
      @parser               = Response::Parser.new
    end

    # Check for premature end-of-file and raise if detected
    #
    # @example
    #   check_premature_eof(:eof)
    #
    # @return [void]
    # @api private
    def check_premature_eof(eof)
      return unless eof && !@parser.finished? && body_framed?

      close
      raise ConnectionError, "response body ended prematurely"
    end

    # Connect socket and set up proxy/TLS
    # @return [void]
    # @api private
    def connect_socket(req, options)
      @socket = options.timeout_class.new(**options.timeout_options) # steep:ignore
      @socket.connect(options.socket_class, req.socket_host, req.socket_port, nodelay: options.nodelay)

      send_proxy_connect_request(req)
      start_tls(req, options)
      reset_timer
    end
  end
end
