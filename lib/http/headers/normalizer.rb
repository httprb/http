# frozen_string_literal: true

module HTTP
  class Headers
    class Normalizer
      # Matches HTTP header names when in "Canonical-Http-Format"
      CANONICAL_NAME_RE = /\A[A-Z][a-z]*(?:-[A-Z][a-z]*)*\z/

      # Matches valid header field name according to RFC.
      # @see http://tools.ietf.org/html/rfc7230#section-3.2
      COMPLIANT_NAME_RE = /\A[A-Za-z0-9!#$%&'*+\-.^_`|~]+\z/

      NAME_PARTS_SEPARATOR_RE = /[\-_]/

      # @private
      # Normalized header names cache
      class Cache
        MAX_SIZE = 200

        def initialize
          @store = {}
        end

        def get(key)
          @store[key]
        end
        alias [] get

        def set(key, value)
          # Maintain cache size
          @store.delete(@store.each_key.first) while MAX_SIZE <= @store.size

          @store[key] = value
        end
        alias []= set
      end

      def initialize
        @cache = Cache.new
      end

      # Transforms `name` to canonical HTTP header capitalization
      def call(name)
        name  = -name.to_s
        value = (@cache[name] ||= -normalize_header(name))

        value.dup
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

        normalized = name.split(NAME_PARTS_SEPARATOR_RE).each(&:capitalize!).join("-")

        return normalized if COMPLIANT_NAME_RE.match?(normalized)

        raise HeaderError, "Invalid HTTP header field name: #{name.inspect}"
      end
    end
  end
end
