module Http
  # We all know what HTTP clients are, right?
  class Client
    include Chainable

    attr_reader :default_options

    def initialize(default_options = {})
      @default_options = Options.new(default_options)
    end

    # Make an HTTP request
    def request(method, uri, options = {})
      opts = @default_options.merge(options)

      # this will have to wait until we have an Http::Request object to yield
      #opts.callbacks[:request].each  { |c| c.call(request) }

      response = perform method, uri, opts.headers, opts.form
      opts.callbacks[:response].each { |c| c.call(response) }

      format_response method, response, opts.response
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
