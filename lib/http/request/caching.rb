require "http/cache/headers"

module HTTP
  class Request
    # Decorator for requests to provide convenience methods related to caching.
    class Caching < DelegateClass(HTTP::Request)
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

      # @return [HTTP::Request::Caching]
      def caching
        self
      end

      # @return [Boolean] true iff request demands the resources cache entry be invalidated
      #
      # @api public
      def invalidates_cache?
        INVALIDATING_METHODS.include?(verb) ||
          cache_headers.no_store?
      end

      # @return [Boolean] true if request is cacheable
      #
      # @api public
      def cacheable?
        CACHEABLE_METHODS.include?(verb) &&
          !cache_headers.no_store?
      end

      # @return [Boolean] true iff the cache control info of this
      # request demands that the response be revalidated by the origin
      # server.
      #
      # @api public
      def skips_cache?
        0 == cache_headers.max_age       ||
          cache_headers.must_revalidate? ||
          cache_headers.no_cache?
      end

      # @return [HTTP::Request::Caching] new request based on this
      # one but conditional on the resource having changed since
      # `cached_response`
      #
      # @api public
      def conditional_on_changes_to(cached_response)
        self.class.new HTTP::Request.new(
          verb, uri, headers.merge(conditional_headers_for(cached_response)),
          proxy, body, version).caching
      end

      # @return [HTTP::Cache::Headers] cache control helper for this request
      # @api public
      def cache_headers
        @cache_headers ||= HTTP::Cache::Headers.new headers
      end

      def env
        {"rack-cache.cache_key" => lambda { |r| r.uri.to_s }}
      end

      private

      # @return [Headers] conditional request headers
      # @api private
      def conditional_headers_for(cached_response)
        headers = HTTP::Headers.new

        cached_response.headers.get("Etag").
          each { |etag| headers.add("If-None-Match", etag) }

        cached_response.headers.get("Last-Modified").
          each { |last_mod| headers.add("If-Modified-Since", last_mod) }

        headers.add("Cache-Control", "max-age=0") if cache_headers.forces_revalidation?

        headers
      end
    end
  end
end
