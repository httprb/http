require "forwardable"

module HTTP
  module Timeout
    class Null
      extend Forwardable

      def_delegators :@socket, :close, :closed?

      attr_reader :socket

      def initialize(_options = {})
      end

      # Connects to a socket
      def connect(socket_class, host, port, nodelay = false)
        @socket = socket_class.open(host, port)
        @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if nodelay
      end

      # Starts a SSL connection on a socket
      def connect_ssl
        @socket.connect
      end

      # Configures the SSL connection and starts the connection
      def start_tls(host, ssl_socket_class, ssl_context)
        @socket = ssl_socket_class.new(socket, ssl_context)
        @socket.hostname = host if @socket.respond_to? :hostname=
        @socket.sync_close = true if @socket.respond_to? :sync_close=

        connect_ssl

        return unless ssl_context.verify_mode == OpenSSL::SSL::VERIFY_PEER

        @socket.post_connection_check(host)
      end

      # Read from the socket
      def readpartial(size)
        @socket.readpartial(size)
      rescue EOFError
        :eof
      end

      # Write to the socket
      def write(data)
        @socket.write(data)
      end
      alias << write

      # These cops can be re-eanbled after we go Ruby 2.0+ only
      # rubocop:disable Lint/UselessAccessModifier, Metrics/BlockNesting

      private

      if RUBY_VERSION < "2.0.0"
        # Retry reading
        def rescue_readable
          yield
        rescue IO::WaitReadable
          retry if IO.select([@socket], nil, nil, read_timeout)
          raise TimeoutError, "Read timed out after #{read_timeout} seconds"
        end

        # Retry writing
        def rescue_writable
          yield
        rescue IO::WaitWritable
          retry if IO.select(nil, [@socket], nil, write_timeout)
          raise TimeoutError, "Write timed out after #{write_timeout} seconds"
        end
      else
        require "io/wait"

        # Retry reading
        def rescue_readable
          yield
        rescue IO::WaitReadable
          retry if @socket.to_io.wait_readable(read_timeout)
          raise TimeoutError, "Read timed out after #{read_timeout} seconds"
        end

        # Retry writing
        def rescue_writable
          yield
        rescue IO::WaitWritable
          retry if @socket.to_io.wait_writable(write_timeout)
          raise TimeoutError, "Write timed out after #{write_timeout} seconds"
        end
      end
    end
  end
end
