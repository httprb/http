require "forwardable"

require "http/client"
require "http/headers"
require "http/response/parser"

module HTTP
  # A connection to the HTTP server
  class Connection
    extend Forwardable

    # Attempt to read this much data
    BUFFER_SIZE = 16_384

    # HTTP/1.0
    HTTP_1_0 = "1.0".freeze

    # HTTP/1.1
    HTTP_1_1 = "1.1".freeze

    # @param [HTTP::Request] req
    # @param [HTTP::Options] options
    def initialize(req, options)
      @persistent           = options.persistent?
      @keep_alive_timeout   = options[:keep_alive_timeout].to_f
      @pending_request      = false
      @pending_response     = false
      @failed_proxy_connect = false

      @parser = Response::Parser.new

      @socket = options[:timeout_class].new(options[:timeout_options])
      @socket.connect(options[:socket_class], req.socket_host, req.socket_port)

      send_proxy_connect_request(req)
      start_tls(req, options)
      reset_timer
    end

    # @see (HTTP::Response::Parser#status_code)
    def_delegator :@parser, :status_code

    # @see (HTTP::Response::Parser#http_version)
    def_delegator :@parser, :http_version

    # @see (HTTP::Response::Parser#headers)
    def_delegator :@parser, :headers

    # @return [Boolean] whenever proxy connect failed
    def failed_proxy_connect?
      @failed_proxy_connect
    end

    # Send a request to the server
    #
    # @param [Request] req Request to send to the server
    # @return [nil]
    def send_request(req)
      if @pending_response
        fail StateError, "Tried to send a request while one is pending already. Make sure you read off the body."
      elsif @pending_request
        fail StateError, "Tried to send a request while a response is pending. Make sure you've fully read the body from the request."
      end

      @pending_request = true

      req.stream @socket

      @pending_response = true
      @pending_request  = false
    end

    # Read a chunk of the body
    #
    # @return [String] data chunk
    # @return [nil] when no more data left
    def readpartial(size = BUFFER_SIZE)
      return unless @pending_response

      if read_more(size) == :eof
        finished = true
      else
        finished = @parser.finished?
      end

      chunk = @parser.chunk

      finish_response if finished

      chunk.to_s
    end

    # Reads data from socket up until headers are loaded
    # @return [void]
    def read_headers!
      loop do
        if read_more(BUFFER_SIZE) == :eof
          fail EOFError unless @parser.headers?
          break
        else
          break if @parser.headers?
        end
      end

      set_keep_alive
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE => e
      raise IOError, "problem making HTTP request: #{e}"
    end

    # Callback for when we've reached the end of a response
    # @return [void]
    def finish_response
      close unless keep_alive?

      @parser.reset
      @socket.reset_counter if @socket.respond_to?(:reset_counter)
      reset_timer

      @pending_response = false
    end

    # Close the connection
    # @return [void]
    def close
      @socket.close unless @socket.closed?

      @pending_response = false
      @pending_request  = false
    end

    # Whether we're keeping the conn alive
    # @return [Boolean]
    def keep_alive?
      !!@keep_alive && !@socket.closed?
    end

    # Whether our connection has expired
    # @return [Boolean]
    def expired?
      !@conn_expires_at || @conn_expires_at < Time.now
    end

    private

    # Sets up SSL context and starts TLS if needed.
    # @param (see #initialize)
    # @return [void]
    def start_tls(req, options)
      return unless req.uri.https? && !failed_proxy_connect?

      ssl_context = options[:ssl_context]

      unless ssl_context
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.set_params(options[:ssl] || {})
      end

      @socket.start_tls(req.uri.host, options[:ssl_socket_class], ssl_context)
    end

    # Open tunnel through proxy
    def send_proxy_connect_request(req)
      return unless req.uri.https? && req.using_proxy?

      @pending_request = true

      req.connect_using_proxy @socket

      @pending_request = false
      @pending_response = true

      read_headers!

      if @parser.status_code == 200
        @parser.reset
        @pending_response = false
        return
      end

      @failed_proxy_connect = true
    end

    # Resets expiration of persistent connection.
    # @return [void]
    def reset_timer
      @conn_expires_at = Time.now + @keep_alive_timeout if @persistent
    end

    # Store whether the connection should be kept alive.
    # Once we reset the parser, we lose all of this state.
    # @return [void]
    def set_keep_alive
      return @keep_alive = false unless @persistent

      case @parser.http_version
      when HTTP_1_0 # HTTP/1.0 requires opt in for Keep Alive
        @keep_alive = @parser.headers[Headers::CONNECTION] == Client::KEEP_ALIVE
      when HTTP_1_1 # HTTP/1.1 is opt-out
        @keep_alive = @parser.headers[Headers::CONNECTION] != Client::CLOSE
      else # Anything else we assume doesn't supportit
        @keep_alive = false
      end
    end

    # Feeds some more data into parser
    # @return [void]
    def read_more(size)
      return if @parser.finished?

      value = @socket.readpartial(size)
      if value == :eof
        :eof
      elsif value
        @parser << value
      end
    end
  end
end
