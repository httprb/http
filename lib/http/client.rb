module Http
  # We all know what HTTP clients are, right?
  class Client
    # I swear I'll document that nebulous options hash
    def initialize(uri, options = {})
      if uri.is_a? URI
        @uri = uri
      else
        # Why the FUCK can't Net::HTTP do this?
        @uri = URI(uri.to_s)
      end

      @options = {:response => :object}.merge(options)
    end

    # Request a get sans response body
    def head(options = {})
      request :head, options
    end

    # Get a resource
    def get(options = {})
      request :get, options
    end

    # Post to a resource
    def post(options = {})
      request :post, options
    end

    # Put to a resource
    def put(options = {})
      request :put, options
    end

    # Delete a resource
    def delete(options = {})
      request :delete, options
    end

    # Echo the request back to the client
    def trace(options = {})
      request :trace, options
    end

    # Return the methods supported on the given URI
    def options(options = {})
      request :options, options
    end

    # Convert to a transparent TCP/IP tunnel
    def connect(options = {})
      request :connect, options
    end

    # Apply partial modifications to a resource
    def patch(options = {})
      request :patch, options
    end

    # Make an HTTP request
    def request(verb, options = {})
      options = @options.merge(options)

      # prepare raw call arguments
      method    = verb
      uri       = @uri
      headers   = options[:headers] || {}
      form_data = options[:form]

      # make raw call
      net_http_response = raw_http_call(method, uri, headers, form_data)

      # convert the response
      http_response = convert_response(net_http_response)

      case options[:response]
      when :object
        http_response
      when :parsed_body
        http_response.parse_body
      when :body
        http_response.body
      else raise ArgumentError, "invalid response type: #{options[:response]}"
      end
    end

    private

    def raw_http_call(method, uri, headers, form_data = nil)
      # Ensure uri and stringify keys :/
      uri     = URI(uri.to_s) unless uri.is_a? URI
      headers = Hash[headers.map{|k,v| [k.to_s, v]}]

      http = Net::HTTP.new(uri.host, uri.port)

      # Why the FUCK can't Net::HTTP do this either?!
      http.use_ssl = true if uri.is_a? URI::HTTPS

      request_class = Net::HTTP.const_get(method.to_s.capitalize)
      request = request_class.new(uri.request_uri, headers)
      request.set_form_data(form_data) if form_data

      http.request(request)
    end

    def convert_response(net_http_response)
      Http::Response.new.tap do |res|
        net_http_response.each_header do |header, value|
          res[header] = value
        end
        res.status = Integer(net_http_response.code) # WTF again Net::HTTP
        res.body   = net_http_response.body
      end
    end

  end
end
