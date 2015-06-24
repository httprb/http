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

      def connect(socket_class, host, port)
        ::Timeout.timeout(connect_timeout, TimeoutError) do
          @socket = socket_class.open(host, port)
        end
      end

      def connect_ssl
        __rescue_readable do
          __rescue_writable do
            socket.connect_nonblock
          end
        end
      end

      # Read data from the socket
      def readpartial(size)
        __rescue_readable do
          socket.read_nonblock(size)
        end
      end

      # Write data to the socket
      def write(data)
        __rescue_writable do
          socket.write_nonblock(data)
        end
      end
    end
  end
end
