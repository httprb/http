require "timeout"

require "http/timeout/null"

module HTTP
  module Timeout
    class PerOperation < Null
      CONNECT_TIMEOUT = 0.25
      WRITE_TIMEOUT = 0.25
      READ_TIMEOUT = 0.25

      attr_reader :read_timeout, :write_timeout, :connect_timeout

      def initialize(*args)
        super

        @read_timeout = options.fetch(:read_timeout, READ_TIMEOUT)
        @write_timeout = options.fetch(:write_timeout, WRITE_TIMEOUT)
        @connect_timeout = options.fetch(:connect_timeout, CONNECT_TIMEOUT)
      end

      def connect(socket_class, host, port, nodelay = false)
        ::Timeout.timeout(connect_timeout, TimeoutError) do
          @socket = socket_class.open(host, port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if nodelay
        end
      end

      def connect_ssl
        rescue_readable do
          rescue_writable do
            socket.connect_nonblock
          end
        end
      end

      # NIO with exceptions
      if RUBY_VERSION < "2.1.0"
        # Read data from the socket
        def readpartial(size)
          rescue_readable do
            socket.read_nonblock(size)
          end
        rescue EOFError
          :eof
        end

        # Write data to the socket
        def write(data)
          rescue_writable do
            socket.write_nonblock(data)
          end
        rescue EOFError
          :eof
        end

      # NIO without exceptions
      else
        # Read data from the socket
        def readpartial(size)
          loop do
            # JRuby may still raise exceptions on SSL sockets even though
            # we explicitly specify `:exception => false`
            result = rescue_readable do
              socket.read_nonblock(size, :exception => false)
            end

            if result.nil?
              return :eof
            elsif result != :wait_readable
              return result
            end

            unless socket.to_io.wait_readable(read_timeout)
              fail TimeoutError, "Read timed out after #{read_timeout} seconds"
            end
          end
        end

        # Write data to the socket
        def write(data)
          loop do
            # JRuby may still raise exceptions on SSL sockets even though
            # we explicitly specify `:exception => false`
            result = rescue_writable do
              socket.write_nonblock(data, :exception => false)
            end

            return result unless result == :wait_writable

            unless socket.to_io.wait_writable(write_timeout)
              fail TimeoutError, "Read timed out after #{write_timeout} seconds"
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockNesting
    end
  end
end
