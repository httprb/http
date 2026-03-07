# frozen_string_literal: true

module HTTP
  class Connection
    # Internal private methods for Connection
    module Internals
      private

      # Sets up SSL context and starts TLS if needed
      # @param (see Connection#initialize)
      # @return [void]
      # @api private
      def start_tls(req, options)
        return unless req.uri.https? && !failed_proxy_connect?

        ssl_context = options.ssl_context

        unless ssl_context
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl_context.set_params(options.ssl || {})
        end

        @socket.start_tls(req.uri.host, options.ssl_socket_class, ssl_context)
      end

      # Open tunnel through proxy
      # @return [void]
      # @api private
      def send_proxy_connect_request(req)
        return unless req.uri.https? && req.using_proxy?

        @pending_request = true

        req.connect_using_proxy @socket

        @pending_request  = false
        @pending_response = true

        read_headers!
        handle_proxy_connect_response
      end

      # Process the proxy connect response
      # @return [void]
      # @api private
      def handle_proxy_connect_response
        @proxy_response_headers = @parser.headers

        if @parser.status_code != 200
          @failed_proxy_connect = true
          return
        end

        @parser.reset
        @pending_response = false
      end

      # Resets expiration of persistent connection
      # @return [void]
      # @api private
      def reset_timer
        @conn_expires_at = Time.now + @keep_alive_timeout if @persistent
      end

      # Store keep-alive state from parser
      # @return [void]
      # @api private
      def set_keep_alive
        return @keep_alive = false unless @persistent

        @keep_alive =
          case @parser.http_version
          when HTTP_1_0 # HTTP/1.0 requires opt in for Keep Alive
            @parser.headers[Headers::CONNECTION] == KEEP_ALIVE
          when HTTP_1_1 # HTTP/1.1 is opt-out
            @parser.headers[Headers::CONNECTION] != CLOSE
          else # Anything else we assume doesn't support it
            false
          end
      end

      # Feeds some more data into parser
      # @return [void]
      # @raise [SocketReadError] when unable to read from socket
      # @api private
      def read_more(size)
        return if @parser.finished?

        value = @socket.readpartial(size, @buffer)
        if value == :eof
          @parser << ""
          :eof
        elsif value
          @parser << value
        end
      rescue IOError, SocketError, SystemCallError => e
        raise SocketReadError, "error reading from socket: #{e}", e.backtrace
      end
    end
  end
end
