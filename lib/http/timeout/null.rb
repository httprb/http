# frozen_string_literal: true

require "io/wait"

module HTTP
  # Namespace for timeout handlers
  module Timeout
    # Base timeout handler with no timeout enforcement
    class Null
      # Timeout configuration options
      #
      # @example
      #   timeout.options # => {read_timeout: 5}
      #
      # @return [Hash] timeout options
      # @api public
      attr_reader :options

      # The underlying socket
      #
      # @example
      #   timeout.socket
      #
      # @return [Object] the underlying socket
      # @api public
      attr_reader :socket

      # Initializes the null timeout handler
      #
      # @example
      #   HTTP::Timeout::Null.new(read_timeout: 5)
      #
      # @param options [Hash] timeout options
      # @api public
      # @return [HTTP::Timeout::Null]
      def initialize(**options)
        @options = options
      end

      # Connects to a socket
      #
      # @example
      #   timeout.connect(TCPSocket, "example.com", 80)
      #
      # @param [Class] socket_class
      # @param [String] host
      # @param [Integer] port
      # @param [Boolean] nodelay
      # @api public
      # @return [void]
      def connect(socket_class, host, port, nodelay: false)
        @socket = socket_class.open(host, port)
        @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if nodelay
      end

      # Starts a SSL connection on a socket
      #
      # @example
      #   timeout.connect_ssl
      #
      # @api public
      # @return [void]
      def connect_ssl
        @socket.connect
      end

      # Closes the underlying socket
      #
      # @example
      #   timeout.close
      #
      # @api public
      # @return [void]
      def close
        @socket&.close
      end

      # Checks whether the socket is closed
      #
      # @example
      #   timeout.closed?
      #
      # @api public
      # @return [Boolean]
      def closed?
        @socket&.closed?
      end

      # Configures the SSL connection and starts it
      #
      # @example
      #   timeout.start_tls("example.com", ssl_class, ssl_ctx)
      #
      # @param [String] host
      # @param [Class] ssl_socket_class
      # @param [OpenSSL::SSL::SSLContext] ssl_context
      # @api public
      # @return [void]
      def start_tls(host, ssl_socket_class, ssl_context)
        @socket = ssl_socket_class.new(socket, ssl_context)
        @socket.hostname = host if @socket.respond_to? :hostname=
        @socket.sync_close = true if @socket.respond_to? :sync_close=

        connect_ssl

        return unless ssl_context.verify_mode == OpenSSL::SSL::VERIFY_PEER
        return if ssl_context.respond_to?(:verify_hostname) && !ssl_context.verify_hostname

        @socket.post_connection_check(host)
      end

      # Read from the socket
      #
      # @example
      #   timeout.readpartial(1024)
      #
      # @param [Integer] size
      # @param [String, nil] buffer
      # @api public
      # @return [String, :eof]
      def readpartial(size, buffer = nil)
        @socket.readpartial(size, buffer)
      rescue EOFError
        :eof
      end

      # Write to the socket
      #
      # @example
      #   timeout.write("GET / HTTP/1.1")
      #
      # @param [String] data
      # @api public
      # @return [Integer]
      def write(data)
        @socket.write(data)
      end
      alias << write

      private

      # Retries reading on wait readable
      #
      # @api private
      # @return [Object]
      def rescue_readable(timeout = read_timeout)
        yield
      rescue IO::WaitReadable
        retry if @socket.to_io.wait_readable(timeout)
        raise TimeoutError, "Read timed out after #{timeout} seconds"
      end

      # Retries writing on wait writable
      #
      # @api private
      # @return [Object]
      def rescue_writable(timeout = write_timeout)
        yield
      rescue IO::WaitWritable
        retry if @socket.to_io.wait_writable(timeout)
        raise TimeoutError, "Write timed out after #{timeout} seconds"
      end
    end
  end
end
