# frozen_string_literal: true

require "http/headers"
require "openssl"
require "socket"
require "http/uri"

module HTTP
  # Configuration options for HTTP requests and clients
  class Options
    @default_socket_class     = TCPSocket
    @default_ssl_socket_class = OpenSSL::SSL::SSLSocket
    @default_timeout_class    = HTTP::Timeout::Null
    @available_features       = {}

    class << self
      # Default TCP socket class
      #
      # @example
      #   HTTP::Options.default_socket_class # => TCPSocket
      #
      # @return [Class] default socket class
      # @api public
      attr_accessor :default_socket_class

      # Default SSL socket class
      #
      # @example
      #   HTTP::Options.default_ssl_socket_class
      #
      # @return [Class] default SSL socket class
      # @api public
      attr_accessor :default_ssl_socket_class

      # Default timeout handler class
      #
      # @example
      #   HTTP::Options.default_timeout_class
      #
      # @return [Class] default timeout class
      # @api public
      attr_accessor :default_timeout_class

      # Registered feature implementations
      #
      # @example
      #   HTTP::Options.available_features
      #
      # @return [Hash] registered feature implementations
      # @api public
      attr_reader :available_features

      # Returns existing Options or creates new one
      #
      # @example
      #   HTTP::Options.new(response: :auto)
      #
      # @param [HTTP::Options, Hash, nil] options existing Options or Hash to convert
      # @api public
      # @return [HTTP::Options]
      def new(options = nil, **kwargs)
        return options if options.is_a?(self)

        super(**(options || kwargs)) # steep:ignore
      end

      # Returns list of defined option names
      #
      # @example
      #   HTTP::Options.defined_options
      #
      # @api semipublic
      # @return [Array<Symbol>]
      def defined_options
        @defined_options ||= []
      end

      # Registers a feature by name and implementation
      #
      # @example
      #   HTTP::Options.register_feature(:auto_inflate, AutoInflate)
      #
      # @param [Symbol] name
      # @param [Class] impl
      # @api public
      # @return [Class]
      def register_feature(name, impl)
        @available_features[name] = impl
      end

      protected

      # Defines an option with accessor and with_ method
      #
      # @param [Symbol] name
      # @param [Boolean] reader_only
      # @api private
      # @return [void]
      def def_option(name, reader_only: false, &interpreter)
        defined_options << name.to_sym
        interpreter ||= ->(v) { v }

        def_option_accessor(name, reader_only: reader_only)

        define_method(:"with_#{name}") do |value|
          dup { |opts| opts.send(:"#{name}=", instance_exec(value, &interpreter)) } # steep:ignore
        end
      end

      # Define accessor methods for an option
      #
      # @example
      #   def_option_accessor(:timeout, reader_only: false)
      #
      # @return [void]
      # @api private
      def def_option_accessor(name, reader_only:)
        if reader_only
          attr_reader name
        else
          attr_accessor name
          protected :"#{name}="
        end
      end
    end

    # Initializes options with keyword arguments
    #
    # @example
    #   HTTP::Options.new(response: :auto, follow: true)
    #
    # @api public
    # @return [HTTP::Options]
    def initialize(
      response: :auto,
      encoding: nil,
      nodelay: false,
      keep_alive_timeout: 5,
      proxy: {},
      ssl: {},
      headers: {},
      features: {},
      timeout_class: self.class.default_timeout_class,
      timeout_options: {},
      socket_class: self.class.default_socket_class,
      ssl_socket_class: self.class.default_ssl_socket_class,
      params: nil,
      form: nil,
      json: nil,
      body: nil,
      follow: nil,
      retriable: nil,
      base_uri: nil,
      persistent: nil,
      ssl_context: nil
    )
      assign_options(binding)
    end

    # Merges two Options objects
    #
    # @example
    #   opts = HTTP::Options.new.merge(HTTP::Options.new(response: :body))
    #
    # @param [HTTP::Options, Hash] other
    # @api public
    # @return [HTTP::Options]
    def merge(other)
      merged = to_hash.merge(other.to_hash) do |k, v1, v2|
        k == :headers ? v1.merge(v2) : v2
      end

      self.class.new(**merged)
    end

    # Converts options to a Hash
    #
    # @example
    #   HTTP::Options.new.to_hash
    #
    # @api public
    # @return [Hash]
    def to_hash
      self.class.defined_options.to_h { |opt_name| [opt_name, public_send(opt_name)] }
    end

    # Duplicates the options object
    #
    # @example
    #   opts = HTTP::Options.new
    #   opts.dup
    #
    # @api public
    # @return [HTTP::Options]
    def dup
      dupped = super
      yield(dupped) if block_given?
      dupped
    end

    # Returns a feature by name
    #
    # @example
    #   opts = HTTP::Options.new
    #   opts.feature(:auto_inflate)
    #
    # @param [Symbol] name
    # @api public
    # @return [Feature, nil]
    def feature(name)
      features[name]
    end

    private

    # Assigns all option values from the initialize binding
    #
    # @param [Binding] env binding from initialize with keyword argument values
    # @api private
    # @return [void]
    def assign_options(env)
      self.class.defined_options.each do |name|
        value = env.local_variable_get(name)
        value = Headers.coerce(value) if name.eql?(:headers)
        __send__(:"#{name}=", value)
      end
    end

    # Raises an argument error with adjusted backtrace
    #
    # @api private
    # @return [void]
    def argument_error!(message)
      error = Error.new(message)
      error.set_backtrace(caller(1) || [])
      raise error
    end
  end
end

require "http/options/definitions"
