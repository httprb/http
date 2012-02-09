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

      callbacks = options[:callbacks] || {}
      (callbacks[:request] || []).each{|c| c.invoke(request)}

      net_http_response = http.request(request)

      (callbacks[:response] || []).each{|c| c.invoke(net_http_response)}

      response = Http::Response.new
      net_http_response.each_header do |header, value|
        response[header] = value
      end
      response.status = Integer(net_http_response.code) # WTF again Net::HTTP
      response.body   = net_http_response.body

      case options[:response]
      when :object
        response
      when :parsed_body
        response.parse_body
      when :body
        response.body
      else raise ArgumentError, "invalid response type: #{options[:response]}"
      end
    end
  end
end
