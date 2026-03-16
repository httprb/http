# frozen_string_literal: true

require "time"

require "http/features/caching/entry"
require "http/features/caching/in_memory_store"

module HTTP
  module Features
    # HTTP caching feature that stores and reuses responses according to
    # RFC 7234. Only GET and HEAD responses are cached. Supports
    # `Cache-Control`, `Expires`, `ETag`, and `Last-Modified` for freshness
    # checks and conditional revalidation.
    #
    # @example Basic usage with in-memory cache
    #   HTTP.use(:caching).get("https://example.com/")
    #
    # @example With a shared store across requests
    #   store = HTTP::Features::Caching::InMemoryStore.new
    #   client = HTTP.use(caching: { store: store })
    #   client.get("https://example.com/")
    #
    class Caching < Feature
      CACHEABLE_METHODS = Set.new(%i[get head]).freeze
      private_constant :CACHEABLE_METHODS

      # The cache store instance
      #
      # @example
      #   feature.store
      #
      # @return [#lookup, #store] the cache store
      # @api public
      attr_reader :store

      # Initializes the Caching feature
      #
      # @example
      #   Caching.new(store: InMemoryStore.new)
      #
      # @param store [#lookup, #store] cache store instance
      # @return [Caching]
      # @api public
      def initialize(store: InMemoryStore.new)
        @store = store
      end

      # Wraps the HTTP exchange with caching logic
      #
      # Checks the cache before making a request. Returns a cached response
      # if fresh; otherwise adds conditional headers and revalidates. Stores
      # cacheable responses for future use.
      #
      # @example
      #   feature.around_request(request) { |req| perform_exchange(req) }
      #
      # @param request [HTTP::Request]
      # @yield Executes the HTTP exchange
      # @yieldreturn [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def around_request(request)
        return yield(request) unless cacheable_request?(request)

        entry = store.lookup(request)

        return yield(request) unless entry

        return build_cached_response(entry, request) if entry.fresh?

        response = yield(add_conditional_headers(request, entry))

        return revalidate_entry(entry, response, request) if response.status.not_modified?

        response
      end

      # Stores cacheable responses in the cache
      #
      # @example
      #   feature.wrap_response(response)
      #
      # @param response [HTTP::Response]
      # @return [HTTP::Response]
      # @api public
      def wrap_response(response)
        return response unless cacheable_request?(response.request)
        return response unless cacheable_response?(response)

        store_and_freeze_response(response)
      end

      private

      # Revalidate a cached entry with a 304 response
      # @return [HTTP::Response]
      # @api private
      def revalidate_entry(entry, response, request)
        entry.update_headers!(response.headers)
        entry.revalidate!
        build_cached_response(entry, request)
      end

      # Store response in cache and return a new response with eagerly-read body
      # @return [HTTP::Response]
      # @api private
      def store_and_freeze_response(response)
        body_string = String(response)
        store.store(response.request, build_entry(response, body_string))

        Response.new(
          status:        response.code,
          version:       response.version,
          headers:       response.headers,
          proxy_headers: response.proxy_headers,
          body:          body_string,
          request:       response.request
        )
      end

      # Build a cache entry from a response
      # @return [Entry]
      # @api private
      def build_entry(response, body_string)
        Entry.new(
          status:        response.code,
          version:       response.version,
          headers:       response.headers.dup,
          proxy_headers: response.proxy_headers,
          body:          body_string,
          request_uri:   response.uri,
          stored_at:     now
        )
      end

      # Check whether this request method is cacheable
      # @return [Boolean]
      # @api private
      def cacheable_request?(request)
        CACHEABLE_METHODS.include?(request.verb)
      end

      # Check whether this response is cacheable
      # @return [Boolean]
      # @api private
      def cacheable_response?(response)
        return false if response.status < 200
        return false if response.status >= 400

        directives = parse_cache_control(response.headers)
        return false if directives.include?("no-store")

        freshness_info?(response, directives)
      end

      # Whether the response carries enough information to determine freshness
      # @return [Boolean]
      # @api private
      def freshness_info?(response, directives)
        return true if directives.any? { |d| d.start_with?("max-age=") }
        return true if response.headers.include?(Headers::EXPIRES)
        return true if response.headers.include?(Headers::ETAG)

        response.headers.include?(Headers::LAST_MODIFIED)
      end

      # Parse Cache-Control header into a list of directives
      # @return [Array<String>]
      # @api private
      def parse_cache_control(headers)
        String(headers[Headers::CACHE_CONTROL]).downcase.split(",").map(&:strip)
      end

      # Add conditional headers from a cached entry to the request
      # @return [HTTP::Request]
      # @api private
      def add_conditional_headers(request, entry)
        headers = request.headers.dup
        headers[Headers::IF_NONE_MATCH] = entry.headers[Headers::ETAG] # steep:ignore
        headers[Headers::IF_MODIFIED_SINCE] = entry.headers[Headers::LAST_MODIFIED] # steep:ignore

        Request.new(
          verb:    request.verb,
          uri:     request.uri,
          headers: headers,
          proxy:   request.proxy,
          body:    request.body,
          version: request.version
        )
      end

      # Build a response from a cached entry
      # @return [HTTP::Response]
      # @api private
      def build_cached_response(entry, request)
        Response.new(
          status:        entry.status,
          version:       entry.version,
          headers:       entry.headers,
          proxy_headers: entry.proxy_headers,
          body:          entry.body,
          request:       request
        )
      end

      # Current time (extracted for testability)
      # @return [Time]
      # @api private
      def now
        Time.now
      end

      HTTP::Options.register_feature(:caching, self)
    end
  end
end
