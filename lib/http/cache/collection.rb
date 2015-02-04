require "http/headers"

module HTTP
  class Cache
    # Collection of all entries in the cache.
    class CacheEntryCollection
      include Enumerable

      # @yield [CacheEntry] each successive entry in the cache.
      def each(&block)
        @entries.each(&block)
      end

      # @return [Response] the response for the request or nil if
      # there isn't one.
      def [](request)
        entry = detect { |e| e.valid_for?(request) }
        entry.response if entry
      end

      # @return [Response] the specified response after inserting it
      # into the cache.
      def []=(request, response)
        @entries.delete_if { |entry| entry.valid_for?(request) }
        @entries << CacheEntry.new(request, response)
        response
      end

      protected

      def initialize
        @entries = []
      end
    end

    # An entry for a single response in the cache
    class CacheEntry
      attr_reader :request, :response

      # @return [Boolean] true iff this entry is valid for the
      # request.
      def valid_for?(request)
        request.uri == @request.uri &&
          select_request_headers.all? do |key, value|
            request.headers[key] == value
          end
      end

      protected

      # @return [Hash] the headers that matter of matching requests to
      # this response.
      def select_request_headers
        headers = HTTP::Headers.new

        @response.headers.get("Vary").flat_map { |v| v.split(",") }.uniq.each do |name|
          name.strip!
          headers[name] = @request.headers[name] if @request.headers[name]
        end

        headers.to_h
      end

      def initialize(request, response)
        @request, @response = request, response
      end
    end
  end
end
