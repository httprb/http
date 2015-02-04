require "http/cache/cache_control"

module HTTP
  class Request
    # Decorator class for requests to provide convenience methods
    # related to caching.
    class Cached < DelegateClass(HTTP::Request)
      INVALIDATING_METHODS = [:post, :put, :delete, :patch].freeze
      CACHEABLE_METHODS    = [:get, :head].freeze

      # When was this request sent to the server
      #
      # @api public
      attr_accessor :sent_at

      # Inits a new instance
      # @api private
      def initialize(obj)
        super
        @requested_at = nil
        @received_at  = nil
      end

      # @return [HTTP::Request::Cached]
      def cached
        self
      end

      # @return [Boolean] true iff request demands the resources cache entry be invalidated
      #
      # @api public
      def invalidates_cache?
        INVALIDATING_METHODS.include?(verb) ||
          cache_control.no_store?
      end

      # @return [Boolean] true if request is cacheable
      #
      # @api public
      def cacheable?
        CACHEABLE_METHODS.include?(verb) &&
          !cache_control.no_store?
      end

      # @return [Boolean] true iff the cache control info of this
      # request demands that the response be revalidated by the origin
      # server.
      #
      # @api public
      def skips_cache?
        0 == cache_control.max_age       ||
          cache_control.must_revalidate? ||
          cache_control.no_cache?
      end

      # @return [HTTP::Request::Cached] new request based on this
      # one but conditional on the resource having changed since
      # `cached_response`
      #
      # @api public
      def conditional_on_changes_to(cached_response)
        self.class.new HTTP::Request.new(
          verb, uri, headers.merge(conditional_headers_for(cached_response)),
          proxy, body, version)
      end

      # @return [HTTP::Cache::CacheControl] cache control helper for this request
      # @api public
      def cache_control
        @cache_control ||= HTTP::Cache::CacheControl.new(self)
      end

      private

      # @return [Headers] conditional request headers
      # @api private
      def conditional_headers_for(cached_response)
        headers = HTTP::Headers.new

        cached_response.headers.get("Etag")
          .each { |etag| headers.add("If-None-Match", etag) }

        cached_response.headers.get("Last-Modified")
          .each { |last_mod| headers.add("If-Modified-Since", last_mod) }

        headers.add("Cache-Control", "max-age=0") if cache_control.forces_revalidation?

        headers
      end
    end
  end
end
