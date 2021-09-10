# frozen_string_literal: true

require "io/wait"
require "resolv"
require "timeout"

require "http/timeout/null"

module HTTP
  module Timeout
    class Global < Null
      def initialize(*args)
        super

        @timeout = @time_left = options.fetch(:global_timeout)
        @dns_resolver = options.fetch(:dns_resolver) do
          ::Resolv.method(:getaddresses)
        end
      end

      # To future me: Don't remove this again, past you was smarter.
      def reset_counter
        @time_left = @timeout
      end

      def connect(socket_class, host_name, *args)
        connect_operation = lambda do |host_address|
          ::Timeout.timeout(@time_left, TimeoutError) do
            super(socket_class, host_address, *args)
          end
        end
        host_addresses = @dns_resolver.call(host_name)
        # ensure something to iterates
        trying_targets = host_addresses.empty? ? [host_name] : host_addresses
        reset_timer
        trying_iterator = trying_targets.lazy
        error = nil
        begin
          connect_operation.call(trying_iterator.next).tap do
            log_time
          end
        rescue TimeoutError => e
          error = e
          retry
        rescue ::StopIteration
          raise error
        end
      end

      def connect_ssl
        reset_timer

        begin
          @socket.connect_nonblock
        rescue IO::WaitReadable
          IO.select([@socket], nil, nil, @time_left)
          log_time
          retry
        rescue IO::WaitWritable
          IO.select(nil, [@socket], nil, @time_left)
          log_time
          retry
        end
      end

      # Read from the socket
      def readpartial(size, buffer = nil)
        perform_io { read_nonblock(size, buffer) }
      end

      # Write to the socket
      def write(data)
        perform_io { write_nonblock(data) }
      end

      alias << write

      private

      def read_nonblock(size, buffer = nil)
        @socket.read_nonblock(size, buffer, :exception => false)
      end

      def write_nonblock(data)
        @socket.write_nonblock(data, :exception => false)
      end

      # Perform the given I/O operation with the given argument
      def perform_io
        reset_timer

        loop do
          result = yield

          case result
          when :wait_readable then wait_readable_or_timeout
          when :wait_writable then wait_writable_or_timeout
          when NilClass       then return :eof
          else                return result
          end
        rescue IO::WaitReadable
          wait_readable_or_timeout
        rescue IO::WaitWritable
          wait_writable_or_timeout
        end
      rescue EOFError
        :eof
      end

      # Wait for a socket to become readable
      def wait_readable_or_timeout
        @socket.to_io.wait_readable(@time_left)
        log_time
      end

      # Wait for a socket to become writable
      def wait_writable_or_timeout
        @socket.to_io.wait_writable(@time_left)
        log_time
      end

      # Due to the run/retry nature of nonblocking I/O, it's easier to keep track of time
      # via method calls instead of a block to monitor.
      def reset_timer
        @started = Time.now
      end

      def log_time
        @time_left -= (Time.now - @started)
        raise TimeoutError, "Timed out after using the allocated #{@timeout} seconds" if @time_left <= 0

        reset_timer
      end
    end
  end
end
