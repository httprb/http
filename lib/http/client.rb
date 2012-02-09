module Http
  # We all know what HTTP clients are, right?
  class Client

    # Request a get sans response body
    def head(uri, options = {})
      request :head, uri, options
    end

    # Get a resource
    def get(uri, options = {})
      request :get, uri, options
    end

    # Post to a resource
    def post(uri, options = {})
      request :post, uri, options
    end

    # Put to a resource
    def put(uri, options = {})
      request :put, uri, options
    end

    # Delete a resource
    def delete(uri, options = {})
      request :delete, uri, options
    end

    # Echo the request back to the client
    def trace(uri, options = {})
      request :trace, uri, options
    end

    # Return the methods supported on the given URI
    def options(uri, options = {})
      request :options, uri, options
    end

    # Convert to a transparent TCP/IP tunnel
    def connect(uri, options = {})
      request :connect, uri, options
    end

    # Apply partial modifications to a resource
    def patch(uri, options = {})
      request :patch, uri, options
    end

    # Make an HTTP request
    def request(method, uri, options = {})
      # prepare raw call arguments
      headers   = options[:headers] || {}
      form_data = options[:form]
      callbacks = options[:callbacks] || {}

      # this will have to wait until we have an Http::Request object to yield
      #callbacks[:request].each  { |c| c.invoke(request) } if callbacks[:request]

      response = perform method, uri, headers, form_data
      callbacks[:response].each { |c| c.invoke(response) } if callbacks[:response]

      format_response response, options[:response]
    end

    #######
    private
    #######

    def perform(method, uri, headers, form_data = nil)
      uri = URI(uri.to_s) unless uri.is_a? URI
      headers = Hash[headers.map{|k,v| [k.to_s, v]}]

      http = Net::HTTP.new(uri.host, uri.port)

      # Why the FUCK can't Net::HTTP do this either?!
      http.use_ssl = true if uri.is_a? URI::HTTPS

      request_class = Net::HTTP.const_get(method.to_s.capitalize)
      request = request_class.new(uri.request_uri, headers)
      request.set_form_data(form_data) if form_data

      response = http.request(request)

      Http::Response.new.tap do |res|
        response.each_header do |header, value|
          res[header] = value
        end

        res.status = Integer(response.code)
        res.body   = response.body
      end
    end

    def format_response(response, option)
      case option
      when :object, NilClass
        response
      when :parsed_body
        response.parse_body
      when :body
        response.body
      else raise ArgumentError, "invalid response type: #{option}"
      end
    end
  end
end
