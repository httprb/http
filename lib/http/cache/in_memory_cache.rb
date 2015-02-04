require "thread"
require "http/cache/collection"

module HTTP
  class Cache
    class InMemoryCache
      # @return [Response] the response for the request or nil if one
      # isn't found
      def lookup(request)
        @mutex.synchronize do
          response = @collection[request.uri.to_s][request]
          response
        end
      end

      # Stores response to be looked up later.
      def store(request, response)
        @mutex.synchronize do
          @collection[request.uri.to_s][request] = response
        end
      end

      # Invalidates the all responses from the specified resource.
      def invalidate(uri)
        @mutex.synchronize do
          @collection.delete(uri.to_s)
        end
      end

      protected

      def initialize
        @mutex = Mutex.new
        @collection = Hash.new { |h, k| h[k] = CacheEntryCollection.new }
      end
    end
  end
end
