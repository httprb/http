require "time"
require "rack-cache"

module HTTP
  class Cache
    # NoOp cache. Always makes the request.
    class NullCache
      # @return [Response] the result of the provided block
      # @yield [request, options] so that the request can actually be made
      def perform(request, options)
        yield(request, options)
      end
    end

    # NoOp logger.
    class NullLogger
      def error(_msg = nil)
      end

      def debug(_msg = nil)
      end

      def info(_msg = nil)
      end

      def warn(_msg = nil)
      end
    end

    # @return [Response] a cached response that is valid for the request or
    #   the result of executing the provided block
    #
    # @yield [request, options] on cache miss so that an actual
    # request can be made
    def perform(request, options, &request_performer)
      req = request.caching

      invalidate_cache(req) if req.invalidates_cache?

      get_response(req, options, request_performer)
    end

    protected

    # @return [Response] the response to the request, either from the
    # cache or by actually making the request
    def get_response(req, options, request_performer)
      cached_resp = cache_lookup(req)
      return cached_resp if cached_resp && !cached_resp.stale?

      # cache miss
      logger.debug { "Cache miss for <#{req.uri}>, making request" }
      actual_req = if cached_resp
                     req.conditional_on_changes_to(cached_resp)
                   else
                     req
                   end
      actual_resp = make_request(actual_req, options, request_performer)

      handle_response(cached_resp, actual_resp, req)
    end

    # @returns [Response] the most useful of the responses after
    # updating the cache as appropriate
    def handle_response(cached_resp, actual_resp, req)
      if actual_resp.status.not_modified? && cached_resp
        logger.debug { "<#{req.uri}> not modified, using cached version." }
        cached_resp.validated!(actual_resp)
        store_in_cache(req, cached_resp)
        return cached_resp

      elsif req.cacheable? && actual_resp.cacheable?
        store_in_cache(req, actual_resp)
        return actual_resp

      else
        return actual_resp
      end
    end

    # @return [HTTP::Response::Caching] the actual response returned
    # by request_performer
    def make_request(req, options, request_performer)
      req.sent_at = Time.now

      request_performer.call(req, options).caching.tap do |res|
        res.received_at  = Time.now
        res.requested_at = req.sent_at
      end
    end

    # @return [HTTP::Response::Caching, nil] the cached response for the request
    def cache_lookup(request)
      return nil if request.skips_cache?

      rack_resp = metastore.lookup(request, entitystore)
      return if rack_resp.nil?

      HTTP::Response.new(
        rack_resp.status, "1.1", rack_resp.headers, stringify(rack_resp.body)
      ).caching
    end

    # Store response in cache
    #
    # @return [nil]
    #
    # ---
    #
    # We have to convert the response body in to a string body so
    # that the cache store reading the body will not prevent the
    # original requester from doing so.
    def store_in_cache(request, response)
      response.body = response.body.to_s
      metastore.store(request, response, entitystore)
      nil
    end

    # Invalidate all response from the requested resource
    #
    # @return [nil]
    def invalidate_cache(request)
      metastore.invalidate(request, entitystore)
    end

    # Inits a new instance
    #
    # @option opts [String] :metastore   URL to the metastore location
    # @option opts [String] :entitystore URL to the entitystore location
    # @option opts [Logger] :logger      logger to use
    def initialize(opts)
      @metastore   = storage.resolve_metastore_uri(opts.fetch(:metastore))
      @entitystore = storage.resolve_entitystore_uri(opts.fetch(:entitystore))
      @logger = opts.fetch(:logger) { NullLogger.new }
    end

    attr_reader :metastore, :entitystore, :logger

    def storage
      @@storage ||= Rack::Cache::Storage.new # rubocop:disable Style/ClassVars
    end

    def stringify(body)
      if body.respond_to?(:each)
        "".tap do |buf|
          body.each do |part|
            buf << part
          end
        end
      else
        body.to_s
      end
    end
  end
end
