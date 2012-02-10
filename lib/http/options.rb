module Http
  class Options

    # How to format the response [:object, :body, :parse_body] 
    attr_accessor :response

    # Http headers to include in the request
    attr_accessor :headers

    # Form data to embed in the request
    attr_accessor :form

    # Before callbacks 
    attr_accessor :callbacks

    protected :response=, :headers=, :form=, :callbacks=

    def self.new(default = {})
      return default if default.is_a?(Options)
      super
    end

    def initialize(default = {})
      @response  = default[:response]  || :object
      @headers   = default[:headers]   || {}
      @form      = default[:form]      || nil
      @callbacks = default[:callbacks] || {:request => [], :response => []}
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
      unless [:request, :response].include?(event)
        raise ArgumentError, "invalid callback event: #{event}"
      end
      dup do |opts|
        opts.callbacks = callbacks.dup
        opts.callbacks[event] = (callbacks[event].dup << callback)
      end
    end

    def [](option)
      send(option) rescue nil
    end

    def to_hash
      {:response  => response,
       :headers   => headers,
       :form      => form,
       :callbacks => callbacks}
    end

    def dup
      dupped = super
      yield(dupped) if block_given?
      dupped
    end

  end
end
