module Http
  class Response
    attr_accessor :status
    attr_accessor :headers
    attr_accessor :body

    # Status aliases! TIMTOWTDI!!! (Want to be idiomatic? Just use status :)
    alias_method :code,  :status
    alias_method :code=, :status=

    alias_method :status_code,  :status
    alias_method :status_code=, :status

    def initialize
      @headers = {}
    end

    # Set a header value
    def []=(header, value)
      key = header.to_s.downcase

      # Check if the header has already been set and group
      old_value = @headers[key]
      if old_value
        @headers[key] = [old_value].flatten << key
      else
        @headers[key] = value
      end
    end

    # Get a header value
    def [](header)
      @headers[header.to_s.downcase]
    end

    # Parse the response body according to its content type
    def parse_body
      if @headers['content-type']
        mime_type = MimeType[@headers['content-type'].split(/;\s*/).first]
        return mime_type.parse(@body) if mime_type
      end

      @body
    end

    # Returns an Array ala Rack: `[status, headers, body]`
    def to_a
      [status, headers, parse_body]
    end
  end
end
