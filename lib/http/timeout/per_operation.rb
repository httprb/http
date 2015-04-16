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
        socket.connect_nonblock
      rescue IO::WaitReadable
        if IO.select([socket], nil, nil, connect_timeout)
          retry
        else
          raise TimeoutError, "Connection timed out after #{connect_timeout} seconds"
        end
      rescue IO::WaitWritable
        if IO.select(nil, [socket], nil, connect_timeout)
          retry
        else
          raise TimeoutError, "Connection timed out after #{connect_timeout} seconds"
        end
      end

      # NIO with exceptions
      # rubocop:disable Metrics/BlockNesting
      if RUBY_VERSION < "2.1.0"
        # Read data from the socket
        def readpartial(size)
          socket.read_nonblock(size)
        rescue IO::WaitReadable
          if IO.select([socket], nil, nil, read_timeout)
            retry
          else
            raise TimeoutError, "Read timed out after #{read_timeout} seconds"
          end
        rescue EOFError
          :eof
        end

        # Write data to the socket
        def write(data)
          socket.write_nonblock(data)
        rescue IO::WaitWritable
          if IO.select(nil, [socket], nil, write_timeout)
            retry
          else
            raise TimeoutError, "Read timed out after #{write_timeout} seconds"
          end
        rescue EOFError
          :eof
        end

      # NIO without exceptions
      else
        # Read data from the socket
        def readpartial(size)
          loop do
            result = socket.read_nonblock(size, :exception => false)
            break result unless result == :wait_readable

            unless IO.select([socket], nil, nil, read_timeout)
              fail TimeoutError, "Read timed out after #{read_timeout} seconds"
            end
          end
        end

        # Write data to the socket
        def write(data)
          loop do
            result = socket.write_nonblock(data, :exception => false)
            break unless result == :wait_writable

            unless IO.select(nil, [socket], nil, write_timeout)
              fail TimeoutError, "Read timed out after #{write_timeout} seconds"
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockNesting
    end
  end
end
