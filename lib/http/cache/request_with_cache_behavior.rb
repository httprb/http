require "http/request"

module HTTP
  class Cache
    # Decorator class for requests to provide convenience methods
    # related to caching. Instantiate using the `.coerce` method.
    class RequestWithCacheBehavior < DelegateClass(HTTP::Request)
      INVALIDATING_METHODS = [:post, :put, :delete, :patch].freeze
      CACHEABLE_METHODS    = [:get, :head].freeze

      class << self
        protected :new

        # Returns a instance of self by wrapping `another` a new
        # instance of self or by just returning it
        def coerce(another)
          if another.respond_to? :cacheable?
            another
          else
            new(another)
          end
        end
      end

      # When was this request sent to the server.
      attr_accessor :sent_at

      # Returns true iff request demands the resources cache entry be invalidated.
      def invalidates_cache?
        INVALIDATING_METHODS.include?(verb) ||
          cache_control.no_store?
      end

      # Returns true iff request is cacheable
      def cacheable?
        CACHEABLE_METHODS.include?(verb) &&
          !cache_control.no_store?
      end

      # Returns true iff the cache control info of this request
      # demands that the response be revalidated by the origin server.
      def skips_cache?
        0 == cache_control.max_age       ||
          cache_control.must_revalidate? ||
          cache_control.no_cache?
      end

      # Returns new request based on this one but conditional on the
      # resource having changed since `cached_response`
      def conditional_on_changes_to(cached_response)
        raw_cond_req = HTTP::Request.new(verb, uri,
                                         headers.merge(conditional_headers_for(cached_response)),
                                         proxy, body, version)

        self.class.coerce(raw_cond_req)
      end

      # Returns cache control helper for this request.
      def cache_control
        @cache_control ||= CacheControl.new(self)
      end

      protected

      def conditional_headers_for(cached_response)
        headers = HTTP::Headers.new

        cached_response.headers.get("Etag")
          .each { |etag| headers.add("If-None-Match", etag) }

        cached_response.headers.get("Last-Modified")
          .each { |last_mod| headers.add("If-Modified-Since", last_mod) }

        headers.add("Cache-Control", "max-age=0") if cache_control.forces_revalidation?

        headers
      end

      def initialize(obj)
        super
        @requested_at = nil
        @received_at  = nil
      end
    end
  end
end
