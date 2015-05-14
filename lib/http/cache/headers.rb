require "delegate"

require "http/errors"
require "http/headers"

module HTTP
  class Cache
    # Convenience methods around cache control headers.
    class Headers < ::SimpleDelegator
      def initialize(headers)
        if headers.is_a? HTTP::Headers
          super headers
        else
          super HTTP::Headers.coerce headers
        end
      end

      # @return [Boolean] does this message force revalidation
      def forces_revalidation?
        must_revalidate? || max_age == 0
      end

      # @return [Boolean] does the cache control include 'must-revalidate'
      def must_revalidate?
        matches?(/\bmust-revalidate\b/i)
      end

      # @return [Boolean] does the cache control include 'no-cache'
      def no_cache?
        matches?(/\bno-cache\b/i)
      end

      # @return [Boolean] does the cache control include 'no-stor'
      def no_store?
        matches?(/\bno-store\b/i)
      end

      # @return [Boolean] does the cache control include 'public'
      def public?
        matches?(/\bpublic\b/i)
      end

      # @return [Boolean] does the cache control include 'private'
      def private?
        matches?(/\bprivate\b/i)
      end

      # @return [Numeric] the max number of seconds this message is
      # considered fresh.
      def max_age
        explicit_max_age || seconds_til_expires || Float::INFINITY
      end

      # @return [Boolean] is the vary header set to '*'
      def vary_star?
        get("Vary").any? { |v| "*" == v.strip }
      end

      private

      # @return [Boolean] true when cache-control header matches the pattern
      def matches?(pattern)
        get("Cache-Control").any? { |v| v =~ pattern }
      end

      # @return [Numeric] number of seconds until the time in the
      # expires header is reached.
      #
      # ---
      # Some servers send a "Expire: -1" header which must be treated as expired
      def seconds_til_expires
        get("Expires").
          map { |e| http_date_to_ttl(e) }.
          max
      end

      def http_date_to_ttl(t_str)
        ttl = to_time_or_epoch(t_str) - Time.now

        ttl < 0 ? 0 : ttl
      end

      # @return [Time] parses t_str at a time; if that fails returns epoch time
      def to_time_or_epoch(t_str)
        Time.httpdate(t_str)
      rescue ArgumentError
        Time.at(0)
      end

      # @return [Numeric] the value of the max-age component of cache control
      def explicit_max_age
        get("Cache-Control").
          map { |v| (/max-age=(\d+)/i).match(v) }.
          compact.
          map { |m| m[1].to_i }.
          max
      end
    end
  end
end
