# frozen_string_literal: true

require "forwardable"

require "http/headers"

module HTTP
  # A connection to the HTTP server
  class Connection
    extend Forwardable

    # Allowed values for CONNECTION header
    KEEP_ALIVE = "Keep-Alive"
    CLOSE      = "close"

    # Attempt to read this much data
    BUFFER_SIZE = 16_384

    # HTTP/1.0
    HTTP_1_0 = "1.0"

    # HTTP/1.1
    HTTP_1_1 = "1.1"

    # Returned after HTTP CONNECT (via proxy)
    attr_reader :proxy_response_headers

    # @param [HTTP::Request] req
    # @param [HTTP::Options] options
    # @raise [HTTP::ConnectionError] when failed to connect
    def initialize(req, options)
      @persistent           = options.persistent?
      @keep_alive_timeout   = options.keep_alive_timeout.to_f
      @pending_request      = false
      @pending_response     = false
      @failed_proxy_connect = false
      @buffer               = "".b

      @parser = Response::Parser.new

      @socket = options.timeout_class.new(options.timeout_options)
      @socket.connect(options.socket_class, req.socket_host, req.socket_port, options.nodelay)

      send_proxy_connect_request(req)
      start_tls(req, options)
      reset_timer
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
        raise StateError, "Tried to send a request while one is pending already. Make sure you read off the body."
      end

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
    # @return [String] data chunk
    # @return [nil] when no more data left
    def readpartial(size = BUFFER_SIZE)
      return unless @pending_response

      chunk = @parser.read(size)
      return chunk if chunk

      finished = (read_more(size) == :eof) || @parser.finished?
      chunk    = @parser.read(size)
      finish_response if finished

      chunk || "".b
    end

    # Reads data from socket up until headers are loaded
    # @return [void]
    # @raise [ResponseHeaderError] when unable to read response headers
    def read_headers!
      until @parser.headers?
        result = read_more(BUFFER_SIZE)
        raise ResponseHeaderError, "couldn't read response headers" if result == :eof
      end

      set_keep_alive
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
      @socket.close unless @socket&.closed?

      @pending_response = false
      @pending_request  = false
    end

    def finished_request?
      !@pending_request && !@pending_response
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

      ssl_context = options.ssl_context

      unless ssl_context
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.set_params(options.ssl || {})
      end

      @socket.start_tls(req.uri.host, options.ssl_socket_class, ssl_context)
    end

    # Open tunnel through proxy
    def send_proxy_connect_request(req)
      return unless req.using_proxy?

      if req.using_socks5_proxy?
        connect_via_socks5(req)
      elsif req.uri.https? && req.using_http_proxy?
        connect_via_http_proxy(req)
      end
    end

    # Connect via HTTP proxy
    def connect_via_http_proxy(req)
      @pending_request = true

      req.connect_using_proxy @socket

      @pending_request  = false
      @pending_response = true

      read_headers!
      @proxy_response_headers = @parser.headers

      if @parser.status_code != 200
        @failed_proxy_connect = true
        return
      end

      @parser.reset
      @pending_response = false
    end

    # Connect via SOCKS5 proxy
    def connect_via_socks5(req)
      # SOCKS5 protocol implementation
      # See RFC 1928: https://tools.ietf.org/html/rfc1928

      # Initial handshake
      auth_methods = [0x00] # No authentication
      if req.using_authenticated_proxy?
        auth_methods << 0x02 # Username/Password authentication
      end

      # Send handshake request
      handshake = [0x05, auth_methods.size, *auth_methods].pack("C*")
      @socket.write(handshake)

      # Read handshake response
      response = @socket.read(2)
      version, auth_method = response.unpack("C*")

      if version != 0x05
        @failed_proxy_connect = true
        raise ConnectionError, "SOCKS5 proxy server returned invalid version: #{version}"
      end

      if auth_method == 0xFF
        @failed_proxy_connect = true
        raise ConnectionError, "SOCKS5 proxy server doesn't support any of our authentication methods"
      end

      # Handle authentication if required
      if auth_method == 0x02 && req.using_authenticated_proxy?
        # Username/Password authentication (RFC 1929)
        username = req.proxy[:proxy_username].to_s
        password = req.proxy[:proxy_password].to_s

        auth_request = [0x01, username.bytesize, username, password.bytesize, password].pack("CCA*CA*")
        @socket.write(auth_request)

        auth_response = @socket.read(2)
        auth_version, auth_status = auth_response.unpack("C*")

        if auth_version != 0x01 || auth_status != 0x00
          @failed_proxy_connect = true
          raise ConnectionError, "SOCKS5 proxy authentication failed"
        end
      end

      # Send connection request
      host = req.uri.host
      port = req.uri.port || req.uri.default_port

      # Determine address type and format
      if host =~ /^\d+\.\d+\.\d+\.\d+$/
        # IPv4 address
        atyp = 0x01
        addr = host.split(".").map(&:to_i).pack("C*")
      else
        # Domain name
        atyp = 0x03
        addr = [host.bytesize, host].pack("CA*")
      end

      connect_request = [0x05, 0x01, 0x00, atyp, addr, port].pack("CCCCA*n")
      @socket.write(connect_request)

      # Read connection response
      response = @socket.read(4)
      version, reply, reserved, atyp = response.unpack("C*")

      if version != 0x05
        @failed_proxy_connect = true
        raise ConnectionError, "SOCKS5 proxy server returned invalid version: #{version}"
      end

      if reply != 0x00
        @failed_proxy_connect = true
        error_message = case reply
                        when 0x01 then "general SOCKS server failure"
                        when 0x02 then "connection not allowed by ruleset"
                        when 0x03 then "Network unreachable"
                        when 0x04 then "Host unreachable"
                        when 0x05 then "Connection refused"
                        when 0x06 then "TTL expired"
                        when 0x07 then "Command not supported"
                        when 0x08 then "Address type not supported"
                        else "Unknown error (code: #{reply})"
                        end
        raise ConnectionError, "SOCKS5 proxy connection failed: #{error_message}"
      end

      # Skip the bound address and port in the response
      case atyp
      when 0x01 # IPv4
        @socket.read(4 + 2) # 4 bytes for IPv4 + 2 bytes for port
      when 0x03 # Domain name
        domain_len = @socket.read(1).unpack1("C")
        @socket.read(domain_len + 2) # domain length + 2 bytes for port
      when 0x04 # IPv6
        @socket.read(16 + 2) # 16 bytes for IPv6 + 2 bytes for port
      end

      # Connection established successfully
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

      @keep_alive =
        case @parser.http_version
        when HTTP_1_0 # HTTP/1.0 requires opt in for Keep Alive
          @parser.headers[Headers::CONNECTION] == KEEP_ALIVE
        when HTTP_1_1 # HTTP/1.1 is opt-out
          @parser.headers[Headers::CONNECTION] != CLOSE
        else # Anything else we assume doesn't supportit
          false
        end
    end

    # Feeds some more data into parser
    # @return [void]
    # @raise [SocketReadError] when unable to read from socket
    def read_more(size)
      return if @parser.finished?

      value = @socket.readpartial(size, @buffer)
      if value == :eof
        @parser << ""
        :eof
      elsif value
        @parser << value
      end
    rescue IOError, SocketError, SystemCallError => e
      raise SocketReadError, "error reading from socket: #{e}", e.backtrace
    end
  end
end
