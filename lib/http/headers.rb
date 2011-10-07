module Http
  class Headers
    include Chainable

    def initialize(headers = {})
      @headers = headers
    end

    def []=(field, value)
      @headers[field.downcase] = value
    end

    def [](field)
      @headers[field.downcase]
    end
  end
end
