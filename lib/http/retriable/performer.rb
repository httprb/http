# frozen_string_literal: true

require "http"
require "http/retriable/errors"
require "http/retriable/client"
require "openssl"

module HTTP
  module Retriable
    # Request performing watchdog.
    # @api private
    class Performer
      # Exceptions we should retry
      RETRIABLE_ERRORS = [
        HTTP::TimeoutError,
        HTTP::ConnectionError,
        IO::EAGAINWaitReadable,
        Errno::ECONNRESET,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        OpenSSL::SSL::SSLError,
        EOFError,
        IOError
      ].freeze

      # Default retry delay proc
      DELAY_PROC = proc { |i| 1 + i * rand }

      # @param [Hash] opts
      # @option opts [#to_i] :tries (5)
      # @option opts [#call] :delay (DELAY_PROC)
      def initialize(opts)
        @tries = opts.fetch(:tries, 5).to_i
        @delay = opts.fetch(:delay, DELAY_PROC)
      end

      # Watches request/response execution.
      #
      # If any of {RETRIABLE_ERRORS} occur or response status is `5xx`, retries
      # up to `:tries` amount of times. Sleeps for amount of seconds calculated
      # with `:delay` proc before each retry.
      #
      # @see #initialize
      # @api private
      def perform(client, req)
        i = 0

        while i < @tries
          begin
            res = yield
            return res unless 500 <= res.status.to_i

            # Some servers support Keep-Alive on any response. Thus we should
            # flush response before retry, to avoid state error (when socket
            # has pending response data and we try to write new request).
            # Alternatively, as we don't need response body here at all, we
            # are going to close client, effectivle closing underlying socket
            # and resetting client's state.
            client.close
          rescue *RETRIABLE_ERRORS => e
            client.close
            err = e
          rescue
            client.close
            raise
          end

          sleep @delay.call i
          i += 1
        end

        raise OutOfRetriesError, error_message(req, res&.status, err)
      end

      private

      # Builds out of retries error message.
      #
      # @param req [HTTP::Request]
      # @param status [HTTP::Response::Status, nil]
      # @param exception [Exception, nil]
      def error_message(req, status, exception)
        message = "#{req.verb.to_s.upcase} <#{req.uri}> failed"

        message += " with #{status}" if status
        message += ":#{exception}"   if exception

        message
      end
    end
  end
end
