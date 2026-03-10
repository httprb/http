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
      # @param [Numeric] global_timeout Global timeout in seconds
      # @param [Numeric, nil] read_timeout Read timeout in seconds
      # @param [Numeric, nil] write_timeout Write timeout in seconds
      # @param [Numeric, nil] connect_timeout Connect timeout in seconds
      # @api public
      # @return [HTTP::Timeout::Global]
      def initialize(global_timeout:, read_timeout: nil, write_timeout: nil, connect_timeout: nil)
        super

        @timeout = @time_left = global_timeout
        @read_timeout    = read_timeout
        @write_timeout   = write_timeout
        @connect_timeout = connect_timeout
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
        ::Timeout.timeout(effective_timeout(@connect_timeout), ConnectTimeoutError) do
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
          wait_readable_or_timeout(@connect_timeout)
          retry
        rescue IO::WaitWritable
          wait_writable_or_timeout(@connect_timeout)
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
        perform_io(@read_timeout) { read_nonblock(size, buffer) }
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
        perform_io(@write_timeout) { write_nonblock(data) }
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
      # @param [Numeric, nil] per_op_timeout per-operation timeout limit
      # @api private
      # @return [Object]
      def perform_io(per_op_timeout = nil)
        reset_timer

        loop do
          result = yield
          return handle_io_result(result) unless WAIT_RESULTS.include?(result)

          wait_for_io(result, per_op_timeout)
        rescue IO::WaitReadable then wait_readable_or_timeout(per_op_timeout)
        rescue IO::WaitWritable then wait_writable_or_timeout(per_op_timeout)
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
      # @param [Symbol] result the I/O wait type
      # @param [Numeric, nil] per_op_timeout per-operation timeout limit
      # @api private
      # @return [void]
      def wait_for_io(result, per_op_timeout = nil)
        if result == :wait_readable
          wait_readable_or_timeout(per_op_timeout)
        else
          wait_writable_or_timeout(per_op_timeout)
        end
      end

      # Waits for a socket to become readable
      #
      # @param [Numeric, nil] per_op per-operation timeout limit
      # @api private
      # @return [void]
      def wait_readable_or_timeout(per_op = nil)
        timeout = effective_timeout(per_op)
        result = @socket.to_io.wait_readable(timeout)
        log_time

        raise TimeoutError, "Read timed out after #{per_op} seconds" if per_op && result.nil?
      end

      # Waits for a socket to become writable
      #
      # @param [Numeric, nil] per_op per-operation timeout limit
      # @api private
      # @return [void]
      def wait_writable_or_timeout(per_op = nil)
        timeout = effective_timeout(per_op)
        result = @socket.to_io.wait_writable(timeout)
        log_time

        raise TimeoutError, "Write timed out after #{per_op} seconds" if per_op && result.nil?
      end

      # Computes the effective timeout as the minimum of global and per-operation
      #
      # @param [Numeric, nil] per_op_timeout per-operation timeout limit
      # @api private
      # @return [Numeric]
      def effective_timeout(per_op_timeout)
        return @time_left unless per_op_timeout

        [per_op_timeout, @time_left].min
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
