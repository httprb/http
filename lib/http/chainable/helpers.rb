# frozen_string_literal: true

module HTTP
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

    # Normalize timeout option keys to include _timeout suffix
    #
    # @param [Hash] options timeout options to normalize
    # @return [void]
    # @api private
    def normalize_timeout_keys!(options)
      %i[global read write connect].each do |k|
        next unless options.key? k

        options[:"#{k}_timeout"] = options.delete k
      end
    end
  end
end
