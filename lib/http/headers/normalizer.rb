# frozen_string_literal: true

module HTTP
  class Headers
    # Normalizes HTTP header names to canonical form
    class Normalizer
      # Matches valid header field name according to RFC.
      # @see http://tools.ietf.org/html/rfc7230#section-3.2
      COMPLIANT_NAME_RE = /\A[A-Za-z0-9!#$%&'*+\-.^_`|~]+\z/

      # Pattern matching header name part separators (hyphens and underscores)
      NAME_PARTS_SEPARATOR_RE = /[-_]/

      # Creates a new Normalizer with an empty cache
      #
      # @example
      #   normalizer = HTTP::Headers::Normalizer.new
      #
      # @return [Normalizer]
      # @api public
      def initialize
        @cache = {} #: Hash[String, String]
      end

      # Normalizes a header name to canonical form
      #
      # @example
      #   normalizer.call("content-type")
      #
      # @return [String]
      # @api public
      def call(name)
        name  = name.to_s
        value = (@cache[name] ||= normalize_header(name))

        value.dup
      end

      private

      # Transforms name to canonical HTTP header capitalization
      #
      # @param [String] name
      # @raise [HeaderError] if normalized name does not
      #   match {COMPLIANT_NAME_RE}
      # @return [String] canonical HTTP header name
      # @api private
      def normalize_header(name)
        normalized = name.split(NAME_PARTS_SEPARATOR_RE).each(&:capitalize!).join("-")

        return normalized if COMPLIANT_NAME_RE.match?(normalized)

        raise HeaderError, "Invalid HTTP header field name: #{name.inspect}"
      end
    end
  end
end
