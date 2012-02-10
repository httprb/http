module Http
  class Options

    # How to format the response [:object, :body, :parse_body] 
    attr_accessor :response

    # Http headers to include in the request
    attr_accessor :headers

    # Form data to embed in the request
    attr_accessor :form

    # Before callbacks 
    attr_accessor :before

    # After callbacks 
    attr_accessor :after

    protected :response=, :headers=, :form=, :before=, :after=

    def initialize
      @response = :object
      @headers  = {}
      @form     = nil
      @before   = []
      @after    = []
    end

    def with_response(response)
      unless [:object, :body, :parsed_body].include?(response)
        raise ArgumentError, "invalid response type: #{response}"
      end
      dup do |opts| 
        opts.response = response
      end
    end

    def with_headers(headers)
      unless headers.respond_to?(:to_hash)
        raise ArgumentError, "invalid headers: #{headers}"
      end
      dup do |opts|
        opts.headers = self.headers.merge(headers.to_hash)
      end
    end

    def with_form(form)
      dup do |opts|
        opts.form = form
      end
    end

    def with_callback(event, callback)
      unless callback.respond_to?(:call)
        raise ArgumentError, "invalid callback: #{callback}"
      end
      case event
      when :request, :before
        dup{|opts| opts.before = (self.before.dup << callback) }
      when :response, :after
        dup{|opts| opts.after  = (self.after.dup << callback)  }
      else
        raise ArgumentError, "invalid callback event: #{event}"
      end
    end

    def dup
      dupped = super
      yield(dupped) if block_given?
      dupped
    end

  end
end
