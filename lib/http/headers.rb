module Http
  class Headers
    def initialize(headers = {})
      @headers = headers
    end

    def []=(field, value)
      @headers[field.downcase] = value
    end

    def [](field)
      @headers[field.downcase]
    end

    # Get a URL with the current headers
    def get(uri, options = {})
      headers = @headers.merge(options[:headers] || {})
      options = options.merge(:headers => headers)
      Client.new(uri).get(options)
    end
  end
end
