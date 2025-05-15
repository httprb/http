# frozen_string_literal: true

module HTTP
  # SOCKS5 proxy implementation
  # rubocop:disable Metrics/ClassLength
  class SOCKS5Proxy
    # @param [Socket] socket The socket to use for the connection
    def initialize(socket)
      @socket = socket
      @failed_connect = false
    end

    # Connect to the target host through the SOCKS5 proxy
    # @param [HTTP::Request] req The request to connect
    # @return [void]
    # @raise [HTTP::ConnectionError] if the connection fails
    def connect(req)
      # SOCKS5 protocol implementation
      # See RFC 1928: https://tools.ietf.org/html/rfc1928

      # Perform initial handshake and get the auth method
      auth_method = perform_handshake(req)

      # Handle authentication if required
      authenticate(req) if auth_method == 0x02 && req.using_authenticated_proxy?

      # Send connection request
      send_connection_request(req)

      # Connection established successfully
    end

    # Perform the initial SOCKS5 handshake
    # @param [HTTP::Request] req The request to connect
    # @return [Integer] The authentication method selected by the server
    # @raise [HTTP::ConnectionError] if the handshake fails
    def perform_handshake(req)
      # Initial handshake
      auth_methods = get_auth_methods(req)

      # Send handshake request and get response
      response = send_handshake_request(auth_methods)

      # Validate the response and get the auth method
      validate_handshake_response(response)
    end

    # Get the authentication methods to offer to the server
    # @param [HTTP::Request] req The request to connect
    # @return [Array<Integer>] The authentication methods
    def get_auth_methods(req)
      methods = [0x00] # No authentication
      methods << 0x02 if req.using_authenticated_proxy? # Username/Password authentication
      methods
    end

    # Send the handshake request and get the server's response
    # @param [Array<Integer>] auth_methods The authentication methods to offer
    # @return [Array] The version and authentication method selected by the server
    def send_handshake_request(auth_methods)
      handshake = [0x05, auth_methods.size, *auth_methods].pack("C*")
      @socket.write(handshake)

      # Read handshake response
      response = @socket.readpartial(2)
      version, auth_method = response.unpack("C*")
      [version, auth_method]
    end

    # Validate the handshake response from the server
    # @param [Array] response The version and authentication method from the server
    # @raise [HTTP::ConnectionError] if the handshake fails
    def validate_handshake_response(response)
      version, auth_method = response

      if version != 0x05
        @failed_connect = true
        raise ConnectionError, "SOCKS5 proxy server returned invalid version: #{version}"
      end

      if auth_method == 0xFF
        @failed_connect = true
        raise ConnectionError, "SOCKS5 proxy server doesn't support any of our authentication methods"
      end

      auth_method
    end

    # @return [Boolean] whenever proxy connect failed
    def failed_connect?
      @failed_connect
    end

    private

    # Authenticate with the SOCKS5 proxy using username and password
    # @param [HTTP::Request] req The request containing proxy credentials
    # @return [void]
    # @raise [HTTP::ConnectionError] if authentication fails
    def authenticate(req)
      # Username/Password authentication (RFC 1929)
      username = req.proxy[:proxy_username].to_s
      password = req.proxy[:proxy_password].to_s

      auth_request = [0x01, username.bytesize, username, password.bytesize, password].pack("CCA*CA*")
      @socket.write(auth_request)

      auth_response = @socket.readpartial(2)
      auth_version, auth_status = auth_response.unpack("C*")

      return unless auth_version != 0x01 || auth_status != 0x00

      @failed_connect = true
      raise ConnectionError, "SOCKS5 proxy authentication failed"
    end

    # Send a connection request to the SOCKS5 proxy
    # @param [HTTP::Request] req The request to connect
    # @return [void]
    # @raise [HTTP::ConnectionError] if the connection fails
    def send_connection_request(req)
      host = req.uri.host
      port = req.uri.port || req.uri.default_port

      # Determine address type and format
      atyp, addr = format_address(host)

      # Send the connection request
      send_request(atyp, addr, port)

      # Process the server's response
      atyp = process_response

      # Skip the bound address and port in the response
      skip_bound_address(atyp)
    end

    # Format the address for SOCKS5 protocol
    # @param [String] host The host to connect to
    # @return [Array] The address type and formatted address
    def format_address(host)
      if /^\d+\.\d+\.\d+\.\d+$/.match?(host)
        # IPv4 address
        [0x01, host.split(".").map(&:to_i).pack("C*")]
      else
        # Domain name
        [0x03, [host.bytesize, host].pack("CA*")]
      end
    end

    # Send the connection request to the SOCKS5 proxy
    # @param [Integer] atyp The address type
    # @param [String] addr The formatted address
    # @param [Integer] port The port to connect to
    # @return [void]
    def send_request(atyp, addr, port)
      connect_request = [0x05, 0x01, 0x00, atyp, addr, port].pack("CCCCA*n")
      @socket.write(connect_request)
    end

    # Process the server's response to the connection request
    # @return [Integer] The address type in the response
    # @raise [HTTP::ConnectionError] if the connection fails
    def process_response
      # Read connection response
      response = @socket.readpartial(4)
      version, reply, _, atyp = response.unpack("C*")

      if version != 0x05
        @failed_connect = true
        raise ConnectionError, "SOCKS5 proxy server returned invalid version: #{version}"
      end

      handle_reply_code(reply)

      atyp
    end

    # Handle the reply code from the SOCKS5 proxy
    # @param [Integer] reply The reply code
    # @raise [HTTP::ConnectionError] if the reply indicates an error
    def handle_reply_code(reply)
      return if reply.zero?

      @failed_connect = true
      error_message = get_error_message(reply)
      raise ConnectionError, "SOCKS5 proxy connection failed: #{error_message}"
    end

    # Get the error message for a SOCKS5 reply code
    # @param [Integer] reply The reply code
    # @return [String] The error message
    # rubocop:disable Metrics/MethodLength
    def get_error_message(reply)
      error_messages = {
        0x01 => "general SOCKS server failure",
        0x02 => "connection not allowed by ruleset",
        0x03 => "Network unreachable",
        0x04 => "Host unreachable",
        0x05 => "Connection refused",
        0x06 => "TTL expired",
        0x07 => "Command not supported",
        0x08 => "Address type not supported"
      }

      error_messages.fetch(reply, "Unknown error (code: #{reply})")
    end
    # rubocop:enable Metrics/MethodLength

    # Skip the bound address and port in the response
    # @param [Integer] atyp The address type
    # @return [void]
    def skip_bound_address(atyp)
      case atyp
      when 0x01 # IPv4
        @socket.readpartial(4 + 2) # 4 bytes for IPv4 + 2 bytes for port
      when 0x03 # Domain name
        domain_len = @socket.readpartial(1).unpack1("C")
        @socket.readpartial(domain_len + 2) # domain length + 2 bytes for port
      when 0x04 # IPv6
        @socket.readpartial(16 + 2) # 16 bytes for IPv6 + 2 bytes for port
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
