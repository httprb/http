module HTTP
  # A streamable response body, also easily converted into a string
  class ResponseBody
    include Enumerable

    def initialize(client)
      @client    = client
      @streaming = nil
      @contents  = nil
    end

    # Read exactly the given amount of data
    def read(length)
      stream!
      @client.read(length)
    end

    # Read up to length bytes, but return any data that's available
    def readpartial(length = nil)
      stream!
      @client.readpartial(length)
    end

    # Iterate over the body, allowing it to be enumerable
    def each
      while chunk = readpartial
        yield chunk
      end
    end

    # Eagerly consume the entire body as a string
    def to_s
      return @contents if @contents
      raise "body is being streamed" unless @streaming.nil?

      begin
        @streaming = false
        @contents = ""
        while chunk = @client.readpartial
          @contents << chunk
        end
      rescue
        @contents = nil
        raise
      end

      @contents
    end

    # Assert that the body is actively being streamed
    def stream!
      raise "body has already been consumed" if @streaming == false
      @streaming = true
    end

    # Easier to interpret string inspect
    def inspect
      "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
    end
  end
end
