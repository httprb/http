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

    def initialize(adapter = HTTP::Cache::InMemoryCache.new)
      @cache_adapter = adapter
    end

    # @return [Response] a cached response that is valid for the request or
    #   the result of executing the provided block.
    #
    # Yields request and options to block if when there is a cache
    # miss so that the request can be make for real.
    def perform(request, options, &request_performer)
      req = RequestWithCacheBehavior.coerce(request)

      invalidate_cache(req) if req.invalidates_cache?

      get_response(req, options, request_performer)
    end

    protected

    def get_response(req, options, request_performer)
      cached_resp = cache_lookup(req)
      return cached_resp if cached_resp && !cached_resp.stale?

      # cache miss

      actual_req = if cached_resp
                     req.conditional_on_changes_to(cached_resp)
                   else
                     req
                   end
      actual_resp = make_request(actual_req, options, request_performer)

      handle_response(cached_resp, actual_resp, req)
    end

    def handle_response(cached_resp, actual_resp, req)
      if actual_resp.status.not_modified? && cached_resp
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

    def make_request(req, options, request_performer)
      req.sent_at = Time.now
      ResponseWithCacheBehavior.coerce(request_performer.call(req, options)).tap do |resp|
        resp.received_at  = Time.now
        resp.requested_at = req.sent_at
      end
    end

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
