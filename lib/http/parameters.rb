module Http
  class Parameters
    include Chainable

    def initialize(headers = {})
      self.default_headers = headers
    end

    def []=(field, value)
      default_headers[field.downcase] = value
    end

    def [](field)
      default_headers[field.downcase]
    end
  end
end
