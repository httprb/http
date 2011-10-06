module Http
  # We all know what HTTP clients are, right?
  class Client
    # I swear I'll document that nebulous options hash
    def initialize(uri, options = {})
      # Argument coersion is a bit gnarly, isn't it?
      case uri
      when String
        # Why the FUCK can't Net::HTTP do this?
        @uri = URI.parse(uri)
      when URI
        @uri = uri
      else
        if uri.respond_to :to_uri
          @uri = uri.to_uri
        else
          raise ArgumentError, "can't convert #{uri.class} to a URI"
        end
      end

      @options = options
    end

    # Make an HTTP get request
    def get(options = {})
      # Red, green, refactor tomorrow :/
      options = @options.merge(options)
      raw_headers = options[:headers] || {}

      # Stringify keys :/
      headers = {}
      raw_headers.each { |k,v| headers[k.to_s] = v }

      http = Net::HTTP.new(@uri.host, @uri.port)

      # Why the FUCK can't Net::HTTP do this either?!
      http.use_ssl = true if @uri.is_a? URI::HTTPS

      request = Net::HTTP::Get.new(@uri.request_uri, headers)
      response = http.request(request)

      if response['content-type'].match(/^application\/json/)
        return JSON.parse response.body if defined? JSON and JSON.respond_to? :parse
      end

      response.body
    end
  end
end
