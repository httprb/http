# Currently broken
# require 'connection_pool'
# require 'redis'
# require 'http/cache/collection'
# require 'digest/sha2'

# module HTTP
#   class Cache
#     class RedisCache
#       def initialize(options = {})
#         @redis = ConnectionPool.new(size: (options[:pool_size] ||5),
#           timeout: (options[:pool_timeout] ||5)) { Redis.new(options) }
#       end

#       def lookup(request)
#         response = cache_entries_for(request)[request]
#         response.authoritative = false if response
#         response
#       end

#       def store(request, response)
#         entries = cache_entries_for(request)

#         @redis.with do |redis|
#           entries[request] = response
#           redis.set(uri_hash(request.uri), Marshal.dump(entries))
#         end
#       end

#       def invalidate(uri)
#         @redis.with do |redis|
#           redis.del(uri_hash(uri))
#         end
#       end

#       private
#       def cache_entries_for(request)
#         @redis.with do |redis|
#           if entries = redis.get(uri_hash(request.uri))
#             Marshal.load(entries)
#           else
#             CacheEntryCollection.new
#           end
#         end
#       end

#       def uri_hash(uri)
#         Digest::SHA2.hexdigest(uri.to_s)
#       end
#     end
#   end
# end
