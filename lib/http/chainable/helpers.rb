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

    # Resolve a timeout hash into a timeout class and normalized options
    #
    # @example
    #   resolve_timeout_hash(global: 60, read: 30)
    #
    # @param [Hash] options timeout options
    # @return [Array(Class, Hash)] timeout class and normalized options
    # @raise [ArgumentError] if options are invalid
    # @api private
    def resolve_timeout_hash(options)
      remaining = options.dup
      global = HTTP::Timeout::PerOperation.send(:extract_global_timeout!, remaining)

      return resolve_global_only(global) if remaining.empty?

      per_op = HTTP::Timeout::PerOperation.normalize_options(remaining)
      global ? [HTTP::Timeout::Global, per_op.merge(global_timeout: global)] : [HTTP::Timeout::PerOperation, per_op]
    end

    # Build options for a global-only timeout from a hash
    #
    # @param [Numeric, nil] global the global timeout value
    # @return [Array(Class, Hash)] timeout class and options
    # @raise [ArgumentError] if no global timeout given
    # @api private
    def resolve_global_only(global)
      raise ArgumentError, "no timeout options given" unless global

      [HTTP::Timeout::Global, { global_timeout: global }]
    end
  end
end
