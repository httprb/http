module Http
  module Chainable
    # Get a URL
    def get(uri, options = {})
      headers = defined?(@headers) ? @headers : {}
      headers = headers.merge(options[:headers] || {})
      options = options.merge(:headers => headers)

      Client.new(uri).get(options)
    end

    # Make a request with the given headers
    def with_headers(headers)
      old_headers = defined?(@headers) ? @headers : {}
      Headers.new old_headers.merge(headers)
    end
    alias_method :with, :with_headers

    # Accept the given MIME type(s)
    def accept(mime_type)
      # Handle shorthand
      case mime_type
      when :json, "json"
        mime_type = "application/json"
      end

      with :accept => mime_type
    end
  end
end
