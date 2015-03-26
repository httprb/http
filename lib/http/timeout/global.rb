# rubocop:disable Lint/HandleExceptions
module HTTP
  module Timeout
    class Global < PerOperation
      attr_reader :time_left, :total_timeout

      def initialize(*args)
        super

        @time_left = connect_timeout + read_timeout + write_timeout
        @total_timeout = time_left
      end

      # Abstracted out from the normal connect for SSL connections
      def connect_with_timeout(*args)
        reset_timer

        begin
          socket.connect_nonblock(*args)

        rescue IO::WaitReadable
          IO.select([socket], nil, nil, time_left)
          log_time
          retry

        rescue Errno::EINPROGRESS
          IO.select(nil, [socket], nil, time_left)
          log_time
          retry

        rescue Errno::EISCONN
        end
      end

      # Read from the socket
      def readpartial(size)
        reset_timer

        begin
          socket.read_nonblock(size)
        rescue IO::WaitReadable
          IO.select([socket], nil, nil, time_left)
          log_time
          retry
        end
      end

      # Write to the socket
      def write(data)
        reset_timer

        begin
          socket << data
        rescue IO::WaitWritable
          IO.select(nil, [socket], nil, time_left)
          log_time
          retry
        end
      end

      private

      # Create a DNS resolver
      def resolve_address(host)
        addr = HostResolver.getaddress(host)
        return addr if addr

        reset_timer

        addr = Resolv::DNS.open(:timeout => time_left) do |dns|
          dns.getaddress
        end

        log_time

        addr

      rescue Resolv::ResolvTimeout
        raise TimeoutError, "DNS timed out after #{total_timeout} seconds"
      end

      # Due to the run/retry nature of nonblocking I/O, it's easier to keep track of time
      # via method calls instead of a block to monitor.
      def reset_timer
        @started = Time.now
      end

      def log_time
        @time_left -= (Time.now - @started)
        if time_left <= 0
          fail TimeoutError, "Timed out after using the allocated #{total_timeout} seconds"
        end

        reset_timer
      end
    end
  end
end
# rubocop:enable Lint/HandleExceptions
