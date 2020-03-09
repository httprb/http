# frozen_string_literal: true

require "date"
require "http"
require "http/retriable/errors"
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

      RETRIABLE_STATUSES = (500...Float::INFINITY).freeze

      # Default retry delay proc
      DELAY_PROC = ->(attempt) {
        delay = 2**(attempt - 1) - 1
        delay_noise = rand
        delay + delay_noise
      }

      # @param [Hash] opts
      # @option opts [#to_i] :tries (5)
      # @option opts [#call, #to_i] :delay (DELAY_PROC)
      # @option opts [Array(Exception)] :exceptions (RETRIABLE_ERRORS)
      # @option opts [Array(#to_i)] :retry_statuses ([500])
      # @option opts [#call] :on_retry
      # @option opts [#to_f] :max_delay (Float::MAX)
      # @option opts [#call] :should_retry
      def initialize(opts)
        @exception_classes = opts.fetch(:exceptions, RETRIABLE_ERRORS)
        @retry_statuses = opts.fetch(:retry_statuses, RETRIABLE_STATUSES)
        @tries = opts.fetch(:tries, 5).to_i
        @on_retry = opts.fetch(:on_retry, ->(*) {})
        @maximum_delay = opts.fetch(:max_delay, Float::MAX).to_f
        @should_retry_proc = opts.fetch(:should_retry, build_retry_proc(@exception_classes, @retry_statuses))
        @delay = build_delay_proc(opts.fetch(:delay, DELAY_PROC))
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
        1.upto(Float::INFINITY) do |attempt| # infinite loop with index
          err, res = try_request { yield }

          if @should_retry_proc.call(req, err, res, attempt)
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
        if response && (retry_header = response.headers["Retry-After"])
          delay_from_retry_header(retry_header)
        else
          calculate_delay_from_iteration(iteration)
        end
      end

      RFC2822_DATE_REGEX = /^
        (?:Sun|Mon|Tue|Wed|Thu|Fri|Sat),\s+
        (?:0[1-9]|[1-2]?[0-9]|3[01])\s+
        (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+
        (?:19[0-9]{2}|[2-9][0-9]{3})\s+
        (?:2[0-3]|[0-1][0-9]):(?:[0-5][0-9]):(?:60|[0-5][0-9])\s+
        GMT
      $/x.freeze

      # Spec for Retry-After header
      # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Retry-After
      def delay_from_retry_header(value)
        value = value.to_s.strip

        delay = case value
                when RFC2822_DATE_REGEX then DateTime.rfc2822(value).to_time - Time.now.utc
                when /^\d+$/            then value.to_i
                else 0
                end

        ensure_dealy_in_bounds(delay)
      end

      def calculate_delay_from_iteration(iteration)
        ensure_dealy_in_bounds(
          @delay.call(iteration)
        )
      end

      def ensure_dealy_in_bounds(delay)
        [0, [delay, @maximum_delay].min].max
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

      def build_retry_proc(exception_classes, retry_statuses)
        retry_statuses = [retry_statuses].flatten

        ->(_req, err, res, _i) {
          if err
            exception_classes.any? { |e| err.is_a?(e) }
          else
            response_status = res.status.to_i
            retry_statuses.any? do |matcher|
              case matcher
              when Range then matcher.include?(response_status)
              when Numeric then matcher == response_status
              else matcher.call(response_status)
              end
            end
          end
        }
      end

      def build_delay_proc(delay)
        case delay
        when Numeric then ->(*) { delay }
        else delay
        end
      end
    end
  end
end
