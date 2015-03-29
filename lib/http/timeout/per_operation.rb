# rubocop:disable Lint/HandleExceptions
require "resolv"

module HTTP
  module Timeout
    class PerOperation < Null
      HostResolver = Resolv::Hosts.new.tap(&:lazy_initialize)

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

      def connect(_, host, port)
        # https://github.com/celluloid/celluloid-io/blob/master/lib/celluloid/io/tcp_socket.rb
        begin
          addr = Resolv::IPv4.create(host)
        rescue ArgumentError
        end

        # Guess it's not IPv4! Is it IPv6?
        begin
          addr ||= Resolv::IPv6.create(host)
        rescue ArgumentError
        end

        unless addr
          addr = resolve_address(host)
          fail Resolv::ResolvError, "DNS result has no information for #{host}" unless addr
        end

        case addr
        when Resolv::IPv4
          family = Socket::AF_INET
        when Resolv::IPv6
          family = Socket::AF_INET6
        else fail ArgumentError, "unsupported address class: #{addr.class}"
        end

        @socket = Socket.new(family, Socket::SOCK_STREAM, 0)

        connect_with_timeout(Socket.sockaddr_in(port, addr.to_s))
      end

      # No changes need to be made for the SSL connection
      alias_method :connect_with_timeout, :connect_ssl

      # Read data from the socket
      def readpartial(size)
        socket.read_nonblock(size)
      rescue IO::WaitReadable
        if IO.select([socket], nil, nil, read_timeout)
          retry
        else
          raise TimeoutError, "Read timed out after #{read_timeout} seconds"
        end
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
      end

      private

      # Actually do the connect after we're setup
      def connect_with_timeout(*args)
        socket.connect_nonblock(*args)

      rescue IO::WaitReadable
        if IO.select([socket], nil, nil, connect_timeout)
          retry
        else
          raise TimeoutError, "Connection timed out after #{connect_timeout} seconds"
        end

      rescue Errno::EINPROGRESS
        if IO.select(nil, [socket], nil, connect_timeout)
          retry
        else
          raise TimeoutError, "Connection timed out after #{connect_timeout} seconds"
        end

      rescue Errno::EISCONN
      end

      # Create a DNS resolver
      def resolve_address(host)
        addr = HostResolver.getaddress(host)
        return addr if addr

        Resolv::DNS.open(:timeout => connect_timeout) do |dns|
          dns.getaddress
        end

      rescue Resolv::ResolvTimeout
        raise TimeoutError, "DNS timed out after #{connect_timeout} seconds"
      end
    end
  end
end
# rubocop:enable Lint/HandleExceptions
