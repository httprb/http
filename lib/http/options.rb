# frozen_string_literal: true

require "http/headers"
require "openssl"
require "socket"
require "http/uri"

module HTTP
  class Options # rubocop:disable Metrics/ClassLength
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
      # @param [Hash] options
      # @api public
      # @return [HTTP::Options]
      def new(options = {})
        options.is_a?(self) ? options : super
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

        if reader_only
          attr_reader name
        else
          attr_accessor name
          protected :"#{name}="
        end

        define_method(:"with_#{name}") do |value|
          dup { |opts| opts.send(:"#{name}=", instance_exec(value, &interpreter)) }
        end
      end
    end

    # Initializes options with defaults
    #
    # @example
    #   HTTP::Options.new(response: :auto, follow: true)
    #
    # @param [Hash] options
    # @api public
    # @return [HTTP::Options]
    def initialize(options = {})
      defaults = {
        response:           :auto,
        proxy:              {},
        timeout_class:      self.class.default_timeout_class,
        timeout_options:    {},
        socket_class:       self.class.default_socket_class,
        nodelay:            false,
        ssl_socket_class:   self.class.default_ssl_socket_class,
        ssl:                {},
        keep_alive_timeout: 5,
        headers:            {},
        cookies:            {},
        encoding:           nil,
        features:           {}
      }

      opts_w_defaults = defaults.merge(options)
      opts_w_defaults[:headers] = HTTP::Headers.coerce(opts_w_defaults[:headers])
      opts_w_defaults.each { |(k, v)| self[k] = v }
    end

    def_option :headers do |new_headers|
      headers.merge(new_headers)
    end

    def_option :cookies do |new_cookies|
      new_cookies.each_with_object cookies.dup do |(k, v), jar|
        cookie = k.is_a?(Cookie) ? k : Cookie.new(k.to_s, v.to_s)
        jar[cookie.name] = cookie.cookie_value
      end
    end

    def_option :encoding do |encoding|
      self.encoding = Encoding.find(encoding)
    end

    def_option :features, reader_only: true do |new_features|
      # Normalize features from:
      #
      #     [{feature_one: {opt: 'val'}}, :feature_two]
      #
      # into:
      #
      #     {feature_one: {opt: 'val'}, feature_two: {}}
      normalized_features = new_features.each_with_object({}) do |feature, h|
        if feature.is_a?(Hash)
          h.merge!(feature)
        else
          h[feature] = {}
        end
      end

      features.merge(normalized_features)
    end

    # Sets and normalizes features hash
    #
    # @param [Hash] features
    # @api private
    # @return [Hash]
    def features=(features)
      @features = features.each_with_object({}) do |(name, opts_or_feature), h|
        h[name] = if opts_or_feature.is_a?(Feature)
                    opts_or_feature
                  else
                    unless (feature = self.class.available_features[name])
                      argument_error! "Unsupported feature: #{name}"
                    end
                    feature.new(**opts_or_feature)
                  end
      end
    end

    %w[
      proxy params form json body response
      socket_class nodelay ssl_socket_class ssl_context ssl
      keep_alive_timeout timeout_class timeout_options
    ].each do |method_name|
      def_option method_name
    end

    def_option :follow, reader_only: true

    # Sets follow redirect options
    #
    # @param [Boolean, Hash, nil] value
    # @api private
    # @return [Hash, nil]
    def follow=(value)
      @follow =
        case
        when !value                    then nil
        when true == value             then {}
        when value.respond_to?(:fetch) then value
        else argument_error! "Unsupported follow options: #{value}"
        end
    end

    def_option :persistent, reader_only: true

    # Sets persistent connection origin
    #
    # @param [String, nil] value
    # @api private
    # @return [String, nil]
    def persistent=(value)
      @persistent = value ? HTTP::URI.parse(value).origin : nil
    end

    # Checks whether persistent connection is enabled
    #
    # @example
    #   opts = HTTP::Options.new(persistent: "http://example.com")
    #   opts.persistent?
    #
    # @api public
    # @return [Boolean]
    def persistent?
      !persistent.nil?
    end

    # Merges two Options objects
    #
    # @example
    #   opts = HTTP::Options.new.merge(HTTP::Options.new(response: :body))
    #
    # @param [HTTP::Options] other
    # @api public
    # @return [HTTP::Options]
    def merge(other)
      h1 = to_hash
      h2 = other.to_hash

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

    # Converts options to a Hash
    #
    # @example
    #   HTTP::Options.new.to_hash
    #
    # @api public
    # @return [Hash]
    def to_hash
      hash_pairs = self.class
                       .defined_options
                       .flat_map { |opt_name| [opt_name, send(opt_name)] }
      Hash[*hash_pairs]
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

    protected

    # Sets an option by name
    #
    # @param [Symbol] option
    # @param [Object] val
    # @api private
    # @return [Object]
    def []=(option, val)
      send(:"#{option}=", val)
    end

    private

    # Raises an argument error with adjusted backtrace
    #
    # @api private
    # @return [void]
    def argument_error!(message)
      raise(Error, message, caller(1..-1))
    end
  end
end
