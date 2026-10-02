# frozen_string_literal: true

module HTTP
  class Client
    # Sends requests over the client's connection, once more on a new
    # connection when a reused one turns out to be closed
    module ConnectionReuse
      private

      # Write the request and read the response headers
      #
      # A reused connection may have been closed by the peer while it sat
      # idle. When that surfaces before any response byte arrives, a
      # replayable request is sent once more on a fresh connection. The resend
      # always starts from a new connection, so it happens at most once.
      #
      # @return [void]
      # @api private
      def transmit(req, options)
        reused = !@connection.nil?
        @connection ||= Connection.new(req, options)
        return if @connection.failed_proxy_connect?

        @connection.send_request(req)
        @connection.read_headers!
      rescue ConnectionError, OpenSSL::SSL::SSLError
        raise unless reused && resend?(req, options)

        @connection.close
        @connection = nil
        retry
      end

      # Whether a request that failed on a reused connection can be resent
      #
      # Explicit retry policies set with {Chainable#retriable} take precedence.
      #
      # @return [Boolean]
      # @api private
      def resend?(req, options)
        !options.retriable && req.replayable? && !@connection.response_started?
      end
    end
  end
end
