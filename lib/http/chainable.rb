module Http
  module Chainable
    # Get a resource
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource
    def post(uri, options = {})
      request :post, uri, options
    end

    # Make an HTTP request with the given verb
    def request(verb, uri, options = {})
      if options[:headers]
        headers = default_headers.merge options[:headers]
      else
        headers = default_headers
      end

      Client.new(uri).request verb, options.merge(:headers => headers)
    end

    # Make a request with the given headers
    def with_headers(headers)
      Parameters.new default_headers.merge(headers)
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

    def default_headers
      @default_headers ||= {}
    end

    def default_headers=(headers)
      @default_headers = headers
    end
  end
end
