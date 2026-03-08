# frozen_string_literal: true

require "timeout"
require "io/wait"

require "http/timeout/null"

module HTTP
  module Timeout
    # Timeout handler with a single global timeout for the entire request
    class Global < Null
      # I/O wait result symbols returned by non-blocking operations
      WAIT_RESULTS = %i[wait_readable wait_writable].freeze
      # Initializes global timeout with options
      #
      # @example
      #   HTTP::Timeout::Global.new(global_timeout: 5)
      #
      # @param [Array] args
      # @api public
      # @return [HTTP::Timeout::Global]
      def initialize(*args)
        super

        @timeout = @time_left = options.fetch(:global_timeout)
      end

      # Resets the time left counter to initial timeout
      #
      # @example
      #   timeout.reset_counter
      #
      # @api public
      # @return [Numeric]
      def reset_counter
        @time_left = @timeout
      end

      # Connects to a socket with global timeout
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
        reset_timer
        ::Timeout.timeout(@time_left, ConnectTimeoutError) do
          @socket = socket_class.open(host, port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if nodelay
        end

        log_time
      end

      # Starts an SSL connection on a socket
      #
      # @example
      #   timeout.connect_ssl
      #
      # @api public
      # @return [void]
      def connect_ssl
        reset_timer

        begin
          @socket.connect_nonblock
        rescue IO::WaitReadable
          wait_readable_or_timeout
          retry
        rescue IO::WaitWritable
          wait_writable_or_timeout
          retry
        end
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
        perform_io { read_nonblock(size, buffer) }
      end

      # Write to the socket
      #
      # @example
      #   timeout.write("GET / HTTP/1.1")
      #
      # @param [String] data
      # @api public
      # @return [Integer, :eof]
      def write(data)
        perform_io { write_nonblock(data) }
      end

      alias << write

      private

      # Reads from socket in non-blocking mode
      #
      # @api private
      # @return [String, Symbol]
      def read_nonblock(size, buffer = nil)
        @socket.read_nonblock(size, buffer, exception: false)
      end

      # Writes to socket in non-blocking mode
      #
      # @api private
      # @return [Integer, Symbol]
      def write_nonblock(data)
        @socket.write_nonblock(data, exception: false)
      end

      # Performs I/O operation with timeout tracking
      #
      # @api private
      # @return [Object]
      def perform_io
        reset_timer

        loop do
          result = yield
          return handle_io_result(result) unless WAIT_RESULTS.include?(result)

          wait_for_io(result)
        rescue IO::WaitReadable then wait_readable_or_timeout
        rescue IO::WaitWritable then wait_writable_or_timeout
        end
      rescue EOFError
        :eof
      end

      # Handles the result of an I/O operation
      #
      # @api private
      # @return [Object, Symbol]
      def handle_io_result(result)
        result.nil? ? :eof : result
      end

      # Waits for an I/O readiness based on the result type
      #
      # @api private
      # @return [void]
      def wait_for_io(result)
        if result == :wait_readable
          wait_readable_or_timeout
        else
          wait_writable_or_timeout
        end
      end

      # Waits for a socket to become readable
      #
      # @api private
      # @return [void]
      def wait_readable_or_timeout
        @socket.to_io.wait_readable(@time_left)
        log_time
      end

      # Waits for a socket to become writable
      #
      # @api private
      # @return [void]
      def wait_writable_or_timeout
        @socket.to_io.wait_writable(@time_left)
        log_time
      end

      # Resets the I/O timer to current time
      #
      # @api private
      # @return [Time]
      def reset_timer
        @started = Time.now
      end

      # Logs elapsed time and checks for timeout
      #
      # @api private
      # @return [void]
      def log_time
        @time_left -= (Time.now - @started)
        raise TimeoutError, "Timed out after using the allocated #{@timeout} seconds" if @time_left <= 0

        reset_timer
      end
    end
  end
end
