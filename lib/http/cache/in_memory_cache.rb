require 'thread'
require 'http/cache/collection'

module HTTP
  class Cache
    class InMemoryCache
      def initialize
        @mutex = Mutex.new
        @collection = Hash.new{ |h,k| h[k] = CacheEntryCollection.new }
      end

      def lookup(request)
        @mutex.synchronize do
          response = @collection[request.uri.to_s][request]
          response.authoritative = false if response
          response
        end
      end

      def store(request, response)
        @mutex.synchronize do
          @collection[request.uri.to_s][request] = response
        end
      end

      def invalidate(uri)
        @mutex.synchronize do
          @collection.delete(uri.to_s)
        end
      end
    end
  end
end
