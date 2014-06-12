require 'http/headers'
require 'openssl'
require 'socket'

module HTTP
  class Options
    # How to format the response [:object, :body, :parse_body]
    attr_accessor :response

    # HTTP headers to include in the request
    attr_accessor :headers

    # Query string params to add to the url
    attr_accessor :params

    # Form data to embed in the request
    attr_accessor :form

    # JSON data to embed in the request
    attr_accessor :json

    # Explicit request body of the request
    attr_accessor :body

    # HTTP proxy to route request
    attr_accessor :proxy

    # Socket classes
    attr_accessor :socket_class, :ssl_socket_class

    # SSL context
    attr_accessor :ssl_context

    # Follow redirects
    attr_accessor :follow

    protected :response=, :headers=, :proxy=, :params=, :form=, :json=, :follow=

    @default_socket_class     = TCPSocket
    @default_ssl_socket_class = OpenSSL::SSL::SSLSocket

    class << self
      attr_accessor :default_socket_class, :default_ssl_socket_class

      def new(options = {})
        return options if options.is_a?(self)
        super
      end
    end

    def initialize(options = {})
      @response  = options[:response]  || :auto
      @proxy     = options[:proxy]     || {}
      @body      = options[:body]
      @params    = options[:params]
      @form      = options[:form]
      @json      = options[:json]
      @follow    = options[:follow]

      @headers   = HTTP::Headers.coerce(options[:headers] || {})

      @socket_class     = options[:socket_class]     || self.class.default_socket_class
      @ssl_socket_class = options[:ssl_socket_class] || self.class.default_ssl_socket_class
      @ssl_context      = options[:ssl_context]
    end

    def with_headers(headers)
      dup do |opts|
        opts.headers = self.headers.merge(headers)
      end
    end

    %w[proxy params form json body follow].each do |method_name|
      class_eval <<-RUBY, __FILE__, __LINE__
        def with_#{method_name}(value)
          dup { |opts| opts.#{method_name} = value }
        end
      RUBY
    end

    def [](option)
      send(option) rescue nil
    end

    def merge(other)
      h1, h2 = to_hash, other.to_hash
      merged = h1.merge(h2) do |k, v1, v2|
        case k
        when :headers
          v1.merge(v2)
        else
          v2
        end
      end

      self.class.new(merged)
    end

    def to_hash
      # FIXME: hardcoding these fields blows! We should have a declarative
      # way of specifying all the options fields, and ensure they *all*
      # get serialized here, rather than manually having to add them each time
      {
        :response         => response,
        :headers          => headers.to_h,
        :proxy            => proxy,
        :params           => params,
        :form             => form,
        :json             => json,
        :body             => body,
        :follow           => follow,
        :socket_class     => socket_class,
        :ssl_socket_class => ssl_socket_class,
        :ssl_context      => ssl_context
      }
    end

    def dup
      dupped = super
      yield(dupped) if block_given?
      dupped
    end

  private

    def argument_error!(message)
      fail(Error, message, caller[1..-1])
    end
  end
end
