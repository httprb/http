module HTTP
  class Cache
    # Convenience methods around cache control headers.
    class CacheControl
      def initialize(message)
        @headers = message.headers
      end

      def forces_revalidation?
        must_revalidate? || max_age == 0
      end

      def must_revalidate?
        matches?(/\bmust-revalidate\b/i)
      end

      def no_cache?
        matches?(/\bno-cache\b/i)
      end

      def no_store?
        matches?(/\bno-store\b/i)
      end

      def public?
        matches?(/\bpublic\b/i)
      end

      def private?
        matches?(/\bprivate\b/i)
      end

      def max_age
        explicit_max_age || seconds_til_expires || Float::INFINITY
      end

      def vary_star?
        headers.get("Vary").any? { |v| "*" == v.strip }
      end

      protected

      attr_reader :headers

      def matches?(pattern)
        headers.get("Cache-Control").any? { |v| v =~ pattern }
      end

      # ---
      # Some servers send a "Expire: -1" header which must be treated as expired
      def seconds_til_expires
        headers.get("Expires")
          .map(&method(:to_time_or_epoch))
          .compact
          .map { |e| e - Time.now }
          .map { |a| a < 0 ? 0 : a } # age is 0 if it is expired
          .max
      end

      def to_time_or_epoch(t_str)
        Time.httpdate(t_str)
      rescue ArgumentError
        Time.at(0)
      end

      def explicit_max_age
        headers.get("Cache-Control")
          .map { |v| (/max-age=(\d+)/i).match(v) }
          .compact
          .map { |m| m[1].to_i }
          .max
      end
    end
  end
end
