# frozen_string_literal: true

module HTTP
  class Headers
    class Normalizer
      # Matches HTTP header names when in "Canonical-Http-Format"
      CANONICAL_NAME_RE = /\A[A-Z][a-z]*(?:-[A-Z][a-z]*)*\z/

      # Matches valid header field name according to RFC.
      # @see http://tools.ietf.org/html/rfc7230#section-3.2
      COMPLIANT_NAME_RE = /\A[A-Za-z0-9!#$%&'*+\-.^_`|~]+\z/

      MAX_CACHE_SIZE = 200

      def initialize
        @cache = LRUCache.new(MAX_CACHE_SIZE)
      end

      # Transforms `name` to canonical HTTP header capitalization
      def normalize(name)
        @cache[name] ||= normalize_header(name)
      end

      private

      # Transforms `name` to canonical HTTP header capitalization
      #
      # @param [String] name
      # @raise [HeaderError] if normalized name does not
      #   match {COMPLIANT_NAME_RE}
      # @return [String] canonical HTTP header name
      def normalize_header(name)
        return name if CANONICAL_NAME_RE.match?(name)

        normalized = name.split(/[\-_]/).each(&:capitalize!).join("-")

        return normalized if COMPLIANT_NAME_RE.match?(normalized)

        raise HeaderError, "Invalid HTTP header field name: #{name.inspect}"
      end

      class LRUCache
        def initialize(max_size)
          @max_size = max_size
          @cache = {}
          @order = []
        end

        def get(key)
          return unless @cache.key?(key)

          # Move the accessed item to the end of the order array
          @order.delete(key)
          @order.push(key)
          @cache[key]
        end

        def set(key, value)
          @cache[key] = value
          @order.push(key)

          # Maintain cache size
          return unless @order.size > @max_size

          oldest = @order.shift
          @cache.delete(oldest)
        end

        def size
          @cache.size
        end

        def key?(key)
          @cache.key?(key)
        end

        def [](key)
          get(key)
        end

        def []=(key, value)
          set(key, value)
        end
      end

      private_constant :LRUCache
    end
  end
end
