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

    # Set a header
    def []=(name, value)
      # If we have a canonical header, we're done
      key = name[CANONICAL_HEADER]

      # Convert to canonical capitalization
      key ||= Http.canonicalize_header(name)

      # Check if the header has already been set and group
      old_value = @headers[key]
      if old_value
        @headers[key] = [old_value].flatten << key
      else
        @headers[key] = value
      end
    end

    # Get a header value
    def [](name)
      @headers[name] || @headers[Http.canonicalize_header(name)]
    end

    # Parse the response body according to its content type
    def parse_body
      if @headers['Content-Type']
        mime_type = MimeType[@headers['Content-Type'].split(/;\s*/).first]
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
