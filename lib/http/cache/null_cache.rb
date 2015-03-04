module HTTP
  class Cache
    # NoOp cache. Always makes the request. Allows avoiding
    # conditionals in the request flow.
    class NullCache
      # @return [Response] the result of the provided block
      # @yield [request, options] so that the request can actually be made
      def perform(request, options)
        yield(request, options)
      end
    end
  end
end
