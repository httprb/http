require "forwardable"

module HTTP
  module Timeout
    class Null
      extend Forwardable

      def_delegators :@socket, :close, :closed?

      attr_reader :options, :socket

      def initialize(options = {})
        @options = options
      end

      # Connects to a socket
      def connect(socket_class, host, port)
        @socket = socket_class.open(host, port)
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
      alias_method :<<, :write

      private

      # Retry reading
      def rescue_readable
        yield
      rescue IO::WaitReadable
        if IO.select([socket], nil, nil, read_timeout)
          retry
        else
          raise TimeoutError, "Read timed out after #{read_timeout} seconds"
        end
      end

      # Retry writing
      def rescue_writable
        yield
      rescue IO::WaitWritable
        if IO.select(nil, [socket], nil, write_timeout)
          retry
        else
          raise TimeoutError, "Write timed out after #{write_timeout} seconds"
        end
      end
    end
  end
end
