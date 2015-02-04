require "http/headers"

module HTTP
  class Cache
    class CacheEntryCollection
      include Enumerable

      def initialize
        @entries = []
      end

      def each(&block)
        @entries.each(&block)
      end

      def [](request)
        entry = find { |e| e.valid_for?(request) }
        entry.response if entry
      end

      def []=(request, response)
        @entries.delete_if { |entry| entry.valid_for?(request) }
        @entries << CacheEntry.new(request, response)
        response
      end
    end

    class CacheEntry
      attr_reader :request, :response

      def initialize(request, response)
        @request, @response = request, response
      end

      def valid_for?(request)
        request.uri == @request.uri &&
          select_request_headers.all? do |key, value|
            request.headers[key] == value
          end
      end

      def select_request_headers
        headers = HTTP::Headers.new

        @response.headers.get("Vary").flat_map { |v| v.split(",") }.uniq.each do |name|
          name.strip!
          headers[name] = @request.headers[name] if @request.headers[name]
        end

        headers.to_h
      end
    end
  end
end
