require "rack-cache"

module HTTP
  class Cache
    # Cache persistence based on rack-cache's storage
    # implementations. See <http://rtomayko.github.io/rack-cache/> for
    # more information.
    class RackCacheStoresAdapter
      # Stores response in cache
      #
      # @return [nil]
      def store(request, response)
        metastore.store(request, response, entitystore)
      end

      # @return [HTTP::Request::Caching, nil] A cached response to
      # request, or nil if one wasn't found
      def lookup(request)
        rack_resp = metastore.lookup(request, entitystore)
        return if rack_resp.nil?

        HTTP::Response.new(
          rack_resp.status, "1.1", rack_resp.headers, stringify(rack_resp.body)
        ).caching
      end

      # Invalidate any cached responses for the request.
      #
      # @return [nil]
      def invalidate(request)
        metastore.invalidate(request, entitystore)
      end

      protected

      # @option opts [String] :metastore The location of the metastore
      # @option opts [String] :entitystore The location of the entity store
      def initialize(opts)
        @metastore   = storage.resolve_metastore_uri(opts[:metastore])
        @entitystore = storage.resolve_entitystore_uri(opts[:entitystore])
      end

      attr_reader :metastore, :entitystore

      def storage
        @@storage ||= Rack::Cache::Storage.new # rubocop:disable Style/ClassVars
      end

      def stringify(body)
        if body.respond_to?(:each)
          String.new.tap do |buf|
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
end
