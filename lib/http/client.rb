require 'uri'

module Http
  # Clients make requests and receive responses
  class Client
    include Chainable

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = Options.new(default_options)
    end

    # Make an HTTP request
    def request(method, uri, options = {})
      opts = @default_options.merge(options)
      headers = opts.headers
      proxy = opts.proxy
      
      if opts.form
        body = URI.encode_www_form(opts.form)
        headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
      end

      request = Request.new method, uri, headers, proxy, body

      opts.callbacks[:request].each { |c| c.call(request) }
      response = perform request
      opts.callbacks[:response].each { |c| c.call(response) }

      format_response method, response, opts.response
    end

    def perform(request)
      uri = request.uri
      proxy = request.proxy

      http = Net::HTTP.new(uri.host, uri.port, proxy[:proxy_address], proxy[:proxy_port], proxy[:proxy_username], proxy[:proxy_password])
      
      http.use_ssl = true if uri.is_a? URI::HTTPS
      response = http.request request.to_net_http_request

      Http::Response.new.tap do |res|
        response.each_header do |header, value|
          res[header] = value
        end

        res.status = Integer(response.code)
        res.body   = response.body
      end
    end

    def format_response(method, response, option)
      case option
      when :auto, NilClass
        method == :head ? response : response.parse_body
      when :object
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
