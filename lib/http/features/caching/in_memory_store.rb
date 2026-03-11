# frozen_string_literal: true

module HTTP
  module Features
    class Caching < Feature
      # Simple in-memory cache store backed by a Hash
      #
      # Cache keys are derived from the request method and URI.
      #
      # @example
      #   store = InMemoryStore.new
      #   store.store(request, entry)
      #   store.lookup(request) # => entry
      #
      class InMemoryStore
        # Create a new empty in-memory store
        #
        # @example
        #   store = InMemoryStore.new
        #
        # @return [InMemoryStore]
        # @api public
        def initialize
          @cache = {}
        end

        # Look up a cached entry for a request
        #
        # @example
        #   store.lookup(request) # => Entry or nil
        #
        # @param request [HTTP::Request]
        # @return [Entry, nil]
        # @api public
        def lookup(request)
          @cache[cache_key(request)]
        end

        # Store a cache entry for a request
        #
        # @example
        #   store.store(request, entry)
        #
        # @param request [HTTP::Request]
        # @param entry [Entry]
        # @return [Entry]
        # @api public
        def store(request, entry)
          @cache[cache_key(request)] = entry
        end

        private

        # Compute the cache key for a request
        # @return [String]
        # @api private
        def cache_key(request)
          format("%s %s", request.verb, request.uri)
        end
      end
    end
  end
end
