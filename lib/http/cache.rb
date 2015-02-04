require "time"
require "http/cache/cache_control"
require "http/cache/response_with_cache_behavior"
require "http/cache/request_with_cache_behavior"

module HTTP
  class Cache
    attr_reader :request, :response

    # NoOp cache. Always makes the request.
    class NullCache
      # Yields request and options to block so that it can make
      # request.
      def perform(request, options)
        yield(request, options)
      end
    end

    def initialize(adapter=HTTP::Cache::InMemoryCache.new)
      @cache_adapter = adapter
    end

    # @return [Response] a cached response that is valid for the request or
    #   the result of executing the provided block.
    #
    # Yields request and options to block if when there is a cache
    # miss so that the request can be make for real.
    def perform(request, options)
      puts "cache is handling request"
      req = RequestWithCacheBehavior.coerce(request)

      if req.invalidates_cache?
        invalidate_cache(req)

      elsif cached_resp = cache_lookup(req)
        return cached_resp unless cached_resp.stale?

        req.set_validation_headers!(cached_resp)
      end

      # cache miss! Do this the hard way...
      req.sent_at = Time.now
      act_resp = ResponseWithCacheBehavior.coerce(yield(req, options))

      act_resp.received_at  = Time.now
      act_resp.requested_at = req.sent_at

      if act_resp.status.not_modified? && cached_resp
        cached_resp.validated!(act_resp)
        store_in_cache(req, cached_resp)
        return cached_resp

      elsif req.cacheable? && act_resp.cacheable?
        store_in_cache(req, act_resp)
        return act_resp

      else
        return act_resp
      end
    end

    protected


    def cache_lookup(request)
      return nil if request.skips_cache?
      c = @cache_adapter.lookup(request)
      if c
        ResponseWithCacheBehavior.coerce(c)
      else
        nil
      end
    end

    def store_in_cache(request, response)
      @cache_adapter.store(request, response)
      nil
    end

    def invalidate_cache(request)
      @cache_adapter.invalidate(request.uri)
    end

  end
end
