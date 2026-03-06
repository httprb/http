# frozen_string_literal: true

require "timeout"

require "http/timeout/null"

module HTTP
  module Timeout
    class PerOperation < Null
      CONNECT_TIMEOUT = 0.25
      WRITE_TIMEOUT = 0.25
      READ_TIMEOUT = 0.25

      # Initializes per-operation timeout with options
      #
      # @example
      #   HTTP::Timeout::PerOperation.new(read_timeout: 5)
      #
      # @param [Array] args
      # @api public
      # @return [HTTP::Timeout::PerOperation]
      def initialize(*args)
        super

        @read_timeout = options.fetch(:read_timeout, READ_TIMEOUT)
        @write_timeout = options.fetch(:write_timeout, WRITE_TIMEOUT)
        @connect_timeout = options.fetch(:connect_timeout, CONNECT_TIMEOUT)
      end

      # Connects to a socket with connect timeout
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
      def connect(socket_class, host, port, nodelay = false)
        ::Timeout.timeout(@connect_timeout, ConnectTimeoutError) do
          @socket = socket_class.open(host, port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if nodelay
        end
      end

      # Starts an SSL connection with connect timeout
      #
      # @example
      #   timeout.connect_ssl
      #
      # @api public
      # @return [void]
      def connect_ssl
        rescue_readable(@connect_timeout) do
          rescue_writable(@connect_timeout) do
            @socket.connect_nonblock
          end
        end
      end

      # Read data from the socket
      #
      # @example
      #   timeout.readpartial(1024)
      #
      # @param [Integer] size
      # @param [String, nil] buffer
      # @api public
      # @return [String, :eof]
      def readpartial(size, buffer = nil)
        timeout = false
        loop do
          result = @socket.read_nonblock(size, buffer, exception: false)

          return :eof   if result.nil?
          return result if result != :wait_readable

          raise TimeoutError, "Read timed out after #{@read_timeout} seconds" if timeout

          # marking the socket for timeout. Why is this not being raised immediately?
          # it seems there is some race-condition on the network level between calling
          # #read_nonblock and #wait_readable, in which #read_nonblock signalizes waiting
          # for reads, and when waiting for x seconds, it returns nil suddenly without completing
          # the x seconds. In a normal case this would be a timeout on wait/read, but it can
          # also mean that the socket has been closed by the server. Therefore we "mark" the
          # socket for timeout and try to read more bytes. If it returns :eof, it's all good, no
          # timeout. Else, the first timeout was a proper timeout.
          # This hack has to be done because io/wait#wait_readable doesn't provide a value for when
          # the socket is closed by the server, and HTTP::Parser doesn't provide the limit for the chunks.
          timeout = true unless @socket.to_io.wait_readable(@read_timeout)
        end
      end

      # Write data to the socket
      #
      # @example
      #   timeout.write("GET / HTTP/1.1")
      #
      # @param [String] data
      # @api public
      # @return [Integer]
      def write(data)
        timeout = false
        loop do
          result = @socket.write_nonblock(data, exception: false)
          return result unless result == :wait_writable

          raise TimeoutError, "Write timed out after #{@write_timeout} seconds" if timeout

          timeout = true unless @socket.to_io.wait_writable(@write_timeout)
        end
      end
    end
  end
end
