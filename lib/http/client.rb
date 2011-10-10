module Http
  # We all know what HTTP clients are, right?
  class Client
    # I swear I'll document that nebulous options hash
    def initialize(uri, options = {})
      if uri.is_a? URI
        @uri = uri
      else
        # Why the FUCK can't Net::HTTP do this?
        @uri = URI(uri)
      end

      @options = {:response => :parsed_body}.merge(options)
    end

    # Request a get sans response body
    def head(uri, options = {})
      request :head, options
    end

    # Get a resource
    def get(uri, options = {})
      request :get, options
    end

    # Post to a resource
    def post(uri, options = {})
      request :post, options
    end

    # Put to a resource
    def put(uri, options = {})
      request :put, options
    end

    # Delete a resource
    def delete(uri, options = {})
      request :delete, options
    end

    # Echo the request back to the client
    def trace(uri, options = {})
      request :trace, options
    end

    # Return the methods supported on the given URI
    def options(uri, options = {})
      request :options, options
    end

    # Convert to a transparent TCP/IP tunnel
    def connect(uri, options = {})
      request :connect, options
    end

    # Apply partial modifications to a resource
    def patch(uri, options = {})
      request :patch, options
    end

    # Make an HTTP request
    def request(verb, options = {})
      # Red, green, refactor tomorrow :/
      options = @options.merge(options)
      raw_headers = options[:headers] || {}

      # Stringify keys :/
      headers = {}
      raw_headers.each { |k,v| headers[k.to_s] = v }

      http = Net::HTTP.new(@uri.host, @uri.port)

      # Why the FUCK can't Net::HTTP do this either?!
      http.use_ssl = true if @uri.is_a? URI::HTTPS

      request_class = Net::HTTP.const_get(verb.to_s.capitalize)
      request = request_class.new(@uri.request_uri, headers)
      request.set_form_data(options[:form]) if options[:form]

      response = http.request(request)

      case options[:response]
      when :parsed_body
        response.body = parse_response(response)
      else
        response.body
      end
      Http::Response.new(response.body, response.code)
    end

    # Parse the response body according to its content type
    def parse_response(response)
      if response['content-type']
        mime_type = MimeType[response['content-type'].split(/;\s*/).first]
        return mime_type.parse(response.body) if mime_type
      end

      response.body
    end
  end
end
