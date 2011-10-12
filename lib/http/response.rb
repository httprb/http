module Http
  class Response
    attr_accessor :body
    attr_accessor :status
    
    def initialize(body, status)
      @body   = body
      @status = status.to_i
    end
  end
end
