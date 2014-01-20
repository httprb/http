require 'http/version'
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

    # Explicit request body of the request
    attr_accessor :body

    # Socket classes
    attr_accessor :socket_class, :ssl_socket_class

    # SSL context
    attr_accessor :ssl_context

    # Follow redirects
    attr_accessor :follow

    protected :response=, :headers=, :params=, :form=, :follow=

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
      @headers   = options[:headers]   || {}
      @body      = options[:body]
      @params    = options[:params]
      @form      = options[:form]
      @follow    = options[:follow]

      @socket_class     = options[:socket_class]     || self.class.default_socket_class
      @ssl_socket_class = options[:ssl_socket_class] || self.class.default_ssl_socket_class
      @ssl_context      = options[:ssl_context]

      @headers['User-Agent'] ||= "RubyHTTPGem/#{HTTP::VERSION}"
    end

    def with_headers(headers)
      unless headers.respond_to?(:to_hash)
        argument_error! "invalid headers: #{headers}"
      end
      dup do |opts|
        opts.headers = self.headers.merge(headers.to_hash)
      end
    end

    def with_params(params)
      dup do |opts|
        opts.params = params
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

    def with_follow(follow)
      dup do |opts|
        opts.follow = follow
      end
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
        :headers          => headers,
        :params           => params,
        :form             => form,
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
      fail(ArgumentError, message, caller[1..-1])
    end
  end
end
