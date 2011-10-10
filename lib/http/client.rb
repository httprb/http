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

      @options = {:parse_response => true}.merge(options)
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

      if options[:parse_response]
        parse_response response
      else
        response.body
      end
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
