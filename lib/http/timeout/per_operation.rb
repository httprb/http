# frozen_string_literal: true

require "timeout"

require "http/timeout/null"

module HTTP
  module Timeout
    # Timeout handler with separate timeouts for connect, read, and write
    class PerOperation < Null
      # Default connect timeout in seconds
      CONNECT_TIMEOUT = 0.25
      # Default write timeout in seconds
      WRITE_TIMEOUT = 0.25
      # Default read timeout in seconds
      READ_TIMEOUT = 0.25

      # Mapping of shorthand option keys to their full forms
      KEYS = %i[read write connect].to_h { |k| [k, :"#{k}_timeout"] }.freeze

      # Normalize and validate timeout options
      #
      # @example
      #   PerOperation.normalize_options(read: 5, write: 3)
      #
      # @param [Hash] options timeout options with short or long keys
      # @return [Hash] normalized options with long keys
      # @raise [ArgumentError] if options are invalid
      # @api public
      def self.normalize_options(options)
        remaining  = options.dup
        normalized = {} #: Hash[Symbol, Numeric]

        KEYS.each do |short, long|
          next if !remaining.key?(short) && !remaining.key?(long)

          normalized[long] = resolve_timeout_value!(remaining, short, long)
        end

        raise ArgumentError, "unknown timeout options: #{remaining.keys.join(', ')}" unless remaining.empty?
        raise ArgumentError, "no timeout options given" if normalized.empty?

        normalized
      end

      # Extract and validate global timeout from options hash
      #
      # @example
      #   extract_global_timeout!({global: 60, read: 5})
      #
      # @param [Hash] options mutable options hash (global key is deleted if found)
      # @return [Numeric, nil] the global timeout value, or nil if not present
      # @raise [ArgumentError] if both forms given or value is not numeric
      # @api private
      private_class_method def self.extract_global_timeout!(options)
        return unless options.key?(:global) || options.key?(:global_timeout)

        resolve_timeout_value!(options, :global, :global_timeout)
      end

      # Resolve a single timeout value from the options hash
      #
      # @example
      #   resolve_timeout_value!({read: 5}, :read, :read_timeout)
      #
      # @param [Hash] options mutable options hash (keys are deleted as consumed)
      # @param [Symbol] short short key name (e.g. :read)
      # @param [Symbol] long long key name (e.g. :read_timeout)
      # @return [Numeric] the timeout value
      # @raise [ArgumentError] if both forms given or value is not numeric
      # @api private
      private_class_method def self.resolve_timeout_value!(options, short, long)
        raise ArgumentError, "can't pass both #{short} and #{long}" if options.key?(short) && options.key?(long)

        value = options.delete(options.key?(long) ? long : short)

        raise ArgumentError, "#{long} must be numeric" unless value.is_a?(Numeric)

        value
      end

      # Initializes per-operation timeout with options
      #
      # @example
      #   HTTP::Timeout::PerOperation.new(read_timeout: 5)
      #
      # @param [Numeric] read_timeout Read timeout in seconds
      # @param [Numeric] write_timeout Write timeout in seconds
      # @param [Numeric] connect_timeout Connect timeout in seconds
      # @api public
      # @return [HTTP::Timeout::PerOperation]
      def initialize(read_timeout: READ_TIMEOUT, write_timeout: WRITE_TIMEOUT, connect_timeout: CONNECT_TIMEOUT)
        super

        @read_timeout = read_timeout
        @write_timeout = write_timeout
        @connect_timeout = connect_timeout
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
      def connect(socket_class, host, port, nodelay: false)
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
