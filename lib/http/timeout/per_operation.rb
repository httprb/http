# frozen_string_literal: true

require "resolv"
require "timeout"

require "http/timeout/null"

module HTTP
  module Timeout
    class PerOperation < Null
      CONNECT_TIMEOUT = 0.25
      WRITE_TIMEOUT = 0.25
      READ_TIMEOUT = 0.25

      def initialize(*args)
        super

        @read_timeout = options.fetch(:read_timeout, READ_TIMEOUT)
        @write_timeout = options.fetch(:write_timeout, WRITE_TIMEOUT)
        @connect_timeout = options.fetch(:connect_timeout, CONNECT_TIMEOUT)
        @dns_resolver = options.fetch(:dns_resolver) do
          ::Resolv.method(:getaddresses)
        end
      end

      # TODO: refactor
      # rubocop:disable Metrics/MethodLength
      def connect(socket_class, host_name, *args)
        connect_operation = lambda do |host_address|
          ::Timeout.timeout(@connect_timeout, TimeoutError) do
            super(socket_class, host_address, *args)
          end
        end
        host_addresses = @dns_resolver.call(host_name)
        # ensure something to iterates
        trying_targets = host_addresses.empty? ? [host_name] : host_addresses
        trying_iterator = trying_targets.lazy
        error = nil
        begin
          connect_operation.call(trying_iterator.next)
        rescue TimeoutError => e
          error = e
          retry
        rescue ::StopIteration
          raise error
        end
      end
      # rubocop:enable Metrics/MethodLength

      def connect_ssl
        rescue_readable(@connect_timeout) do
          rescue_writable(@connect_timeout) do
            @socket.connect_nonblock
          end
        end
      end

      # Read data from the socket
      def readpartial(size, buffer = nil)
        timeout = false
        loop do
          result = @socket.read_nonblock(size, buffer, :exception => false)

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
      def write(data)
        timeout = false
        loop do
          result = @socket.write_nonblock(data, :exception => false)
          return result unless result == :wait_writable

          raise TimeoutError, "Write timed out after #{@write_timeout} seconds" if timeout

          timeout = true unless @socket.to_io.wait_writable(@write_timeout)
        end
      end
    end
  end
end
