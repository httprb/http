# frozen_string_literal: true

module HTTP
  # HTTP verb methods and client configuration DSL
  module Chainable
    # Mapping of proxy argument positions to hash keys and expected types
    PROXY_ARG_MAP = [
      [:proxy_address,  0, String],
      [:proxy_port,     1, Integer],
      [:proxy_username, 2, String],
      [:proxy_password, 3, String],
      [:proxy_headers,  2, Hash],
      [:proxy_headers,  4, Hash]
    ].freeze

    private

    # Build proxy configuration hash from positional arguments
    #
    # @param [Array] proxy positional proxy arguments
    # @return [Hash] proxy configuration
    # @api private
    def build_proxy_hash(proxy)
      result = {} #: Hash[Symbol, untyped]
      PROXY_ARG_MAP.each do |key, index, type|
        result[key] = proxy[index] if proxy[index].is_a?(type)
      end
      result
    end
  end
end
