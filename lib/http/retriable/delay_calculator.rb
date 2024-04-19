# frozen_string_literal: true

module HTTP
  module Retriable
    # @api private
    class DelayCalculator
      def initialize(opts)
        @max_delay = opts.fetch(:max_delay, Float::MAX).to_f
        if (delay = opts[:delay]).respond_to?(:call)
          @delay_proc = opts.fetch(:delay)
        else
          @delay = delay
        end
      end

      def call(iteration, response)
        delay = if response && (retry_header = response.headers["Retry-After"])
                  delay_from_retry_header(retry_header)
                else
                  calculate_delay_from_iteration(iteration)
                end

        ensure_dealy_in_bounds(delay)
      end

      RFC2822_DATE_REGEX = /^
        (?:Sun|Mon|Tue|Wed|Thu|Fri|Sat),\s+
        (?:0[1-9]|[1-2]?[0-9]|3[01])\s+
        (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+
        (?:19[0-9]{2}|[2-9][0-9]{3})\s+
        (?:2[0-3]|[0-1][0-9]):(?:[0-5][0-9]):(?:60|[0-5][0-9])\s+
        GMT
      $/x

      # Spec for Retry-After header
      # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Retry-After
      def delay_from_retry_header(value)
        value = value.to_s.strip

        case value
        when RFC2822_DATE_REGEX then DateTime.rfc2822(value).to_time - Time.now.utc
        when /^\d+$/            then value.to_i
        else 0
        end
      end

      def calculate_delay_from_iteration(iteration)
        if @delay_proc
          @delay_proc.call(iteration)
        elsif @delay
          @delay
        else
          delay = (2**(iteration - 1)) - 1
          delay_noise = rand
          delay + delay_noise
        end
      end

      def ensure_dealy_in_bounds(delay)
        delay.clamp(0, @max_delay)
      end
    end
  end
end
