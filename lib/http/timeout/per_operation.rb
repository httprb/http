# frozen_string_literal: true
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
        rescue_readable(@connect_timeout) do
          rescue_writable(@connect_timeout) do
            @socket.connect_nonblock
          end
        end
      end

      # NIO with exceptions
      if RUBY_VERSION < "2.1.0"
        # Read data from the socket
        def readpartial(size)
          rescue_readable do
            @socket.read_nonblock(size)
          end
        rescue EOFError
          :eof
        end

        # Write data to the socket
        def write(data)
          rescue_writable do
            @socket.write_nonblock(data)
          end
        rescue EOFError
          :eof
        end

      # NIO without exceptions
      else
        # Read data from the socket
        def readpartial(size)
          loop do
            result = @socket.read_nonblock(size, :exception => false)

            return :eof   if result.nil?
            return result if result != :wait_readable

            unless IO.select([@socket], nil, nil, read_timeout)
              raise TimeoutError, "Read timed out after #{read_timeout} seconds"
            end
          end
        end

        # Write data to the socket
        def write(data)
          loop do
            result = @socket.write_nonblock(data, :exception => false)
            return result unless result == :wait_writable

            unless IO.select(nil, [@socket], nil, write_timeout)
              raise TimeoutError, "Write timed out after #{write_timeout} seconds"
            end
          end
        end
      end
    end
  end
end
