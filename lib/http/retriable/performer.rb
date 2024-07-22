# frozen_string_literal: true

require "date"
require "http/retriable/errors"
require "http/retriable/delay_calculator"
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

      # @param [Hash] opts
      # @option opts [#to_i] :tries (5)
      # @option opts [#call, #to_i] :delay (DELAY_PROC)
      # @option opts [Array(Exception)] :exceptions (RETRIABLE_ERRORS)
      # @option opts [Array(#to_i)] :retry_statuses
      # @option opts [#call] :on_retry
      # @option opts [#to_f] :max_delay (Float::MAX)
      # @option opts [#call] :should_retry
      def initialize(opts)
        @exception_classes = opts.fetch(:exceptions, RETRIABLE_ERRORS)
        @retry_statuses = opts[:retry_statuses]
        @tries = opts.fetch(:tries, 5).to_i
        @on_retry = opts.fetch(:on_retry, ->(*) {})
        @should_retry_proc = opts[:should_retry]
        @delay_calculator = DelayCalculator.new(opts)
      end

      # Watches request/response execution.
      #
      # If any of {RETRIABLE_ERRORS} occur or response status is `5xx`, retries
      # up to `:tries` amount of times. Sleeps for amount of seconds calculated
      # with `:delay` proc before each retry.
      #
      # @see #initialize
      # @api private
      def perform(client, req, &block)
        1.upto(Float::INFINITY) do |attempt| # infinite loop with index
          err, res = try_request(&block)

          if retry_request?(req, err, res, attempt)
            begin
              wait_for_retry_or_raise(req, err, res, attempt)
            ensure
              # Some servers support Keep-Alive on any response. Thus we should
              # flush response before retry, to avoid state error (when socket
              # has pending response data and we try to write new request).
              # Alternatively, as we don't need response body here at all, we
              # are going to close client, effectivle closing underlying socket
              # and resetting client's state.
              client.close
            end
          elsif err
            client.close
            raise err
          elsif res
            return res
          end
        end
      end

      def calculate_delay(iteration, response)
        @delay_calculator.call(iteration, response)
      end

      private

      # rubocop:disable Lint/RescueException
      def try_request
        err, res = nil

        begin
          res = yield
        rescue Exception => e
          err = e
        end

        [err, res]
      end
      # rubocop:enable Lint/RescueException

      def retry_request?(req, err, res, attempt)
        if @should_retry_proc
          @should_retry_proc.call(req, err, res, attempt)
        elsif err
          retry_exception?(err)
        else
          retry_response?(res)
        end
      end

      def retry_exception?(err)
        @exception_classes.any? { |e| err.is_a?(e) }
      end

      def retry_response?(res)
        return false unless @retry_statuses

        response_status = res.status.to_i
        retry_matchers = [@retry_statuses].flatten

        retry_matchers.any? do |matcher|
          case matcher
          when Range then matcher.cover?(response_status)
          when Numeric then matcher == response_status
          else matcher.call(response_status)
          end
        end
      end

      def wait_for_retry_or_raise(req, err, res, attempt)
        if attempt < @tries
          @on_retry.call(req, err, res)
          sleep calculate_delay(attempt, res)
        else
          res&.flush
          raise out_of_retries_error(req, res, err)
        end
      end

      # Builds OutOfRetriesError
      #
      # @param request [HTTP::Request]
      # @param status [HTTP::Response, nil]
      # @param exception [Exception, nil]
      def out_of_retries_error(request, response, exception)
        message = "#{request.verb.to_s.upcase} <#{request.uri}> failed"

        message += " with #{response.status}" if response
        message += ":#{exception}" if exception

        HTTP::OutOfRetriesError.new(message).tap do |ex|
          ex.cause = exception
          ex.response = response
        end
      end
    end
  end
end
