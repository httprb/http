require 'socket'
require 'openssl'

module Http
  class Options

    # How to format the response [:object, :body, :parse_body]
    attr_accessor :response

    # Http headers to include in the request
    attr_accessor :headers

    # Form data to embed in the request
    attr_accessor :form

    # Explicit request body of the request
    attr_accessor :body

    # Http proxy to route request
    attr_accessor :proxy

    # Before callbacks
    attr_accessor :callbacks

    # Socket classes
    attr_accessor :socket_class, :ssl_socket_class

    # SSL context
    attr_accessor :ssl_context

    protected :response=, :headers=, :proxy=, :form=,  :callbacks=

    @default_socket_class     = TCPSocket
    @default_ssl_socket_class = OpenSSL::SSL::SSLSocket

    class << self
      attr_accessor :default_socket_class, :default_ssl_socket_class

      def new(options = {})
        return options if options.is_a?(Options)
        super
      end
    end

    def initialize(options = {})
      @response  = options[:response]  || :auto
      @headers   = options[:headers]   || {}
      @proxy     = options[:proxy]     || {}
      @callbacks = options[:callbacks] || {:request => [], :response => []}
      @body      = options[:body]
      @form      = options[:form]

      @socket_class     = options[:socket_class]     || self.class.default_socket_class
      @ssl_socket_class = options[:ssl_socket_class] || self.class.default_ssl_socket_class
      @ssl_context      = options[:ssl_context]
    end

    def with_response(response)
      unless [:auto, :object, :body, :parsed_body].include?(response)
        argument_error! "invalid response type: #{response}"
      end
      dup do |opts|
        opts.response = response
      end
    end

    def with_headers(headers)
      unless headers.respond_to?(:to_hash)
        argument_error! "invalid headers: #{headers}"
      end
      dup do |opts|
        opts.headers = self.headers.merge(headers.to_hash)
      end
    end

    def with_proxy(proxy_hash)
      dup do |opts|
        opts.proxy = proxy_hash
      end
    end

    def with_form(form)
      dup do |opts|
        opts.form = form
      end
    end

    def with_body(body)
      dup do |opts|
        opts.body = body
      end
    end

    def with_callback(event, callback)
      unless callback.respond_to?(:call)
        argument_error! "invalid callback: #{callback}"
      end
      unless callback.respond_to?(:arity) and callback.arity == 1
        argument_error! "callback must accept only one argument"
      end
      unless [:request, :response].include?(event)
        argument_error! "invalid callback event: #{event}"
      end
      dup do |opts|
        opts.callbacks = callbacks.dup
        opts.callbacks[event] = (callbacks[event].dup << callback)
      end
    end

    def [](option)
      send(option) rescue nil
    end

    def merge(other)
      h1, h2 = to_hash, other.to_hash
      merged = h1.merge(h2) do |k,v1,v2|
        case k
        when :headers
          v1.merge(v2)
        when :callbacks
          v1.merge(v2){|event,l,r| (l+r).uniq}
        else
          v2
        end
      end
      Options.new(merged)
    end

    def to_hash
      {:response  => response,
       :headers   => headers,
       :proxy     => proxy,
       :form      => form,
       :body      => body,
       :callbacks => callbacks}
    end

    def dup
      dupped = super
      yield(dupped) if block_given?
      dupped
    end

    private

    def argument_error!(message)
      raise ArgumentError, message, caller[1..-1]
    end

  end
end
