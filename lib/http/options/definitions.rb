# frozen_string_literal: true

module HTTP
  # Configuration options for HTTP requests and clients
  class Options
    def_option :headers do |new_headers|
      headers.merge(new_headers) # steep:ignore
    end

    def_option :encoding do |encoding|
      self.encoding = Encoding.find(encoding) # steep:ignore
    end

    def_option :features, reader_only: true do |new_features|
      # Normalize features from:
      #
      #     [{feature_one: {opt: 'val'}}, :feature_two]
      #
      # into:
      #
      #     {feature_one: {opt: 'val'}, feature_two: {}}
      acc = {} #: Hash[untyped, untyped]
      normalized_features = new_features.each_with_object(acc) do |feature, h|
        if feature.is_a?(Hash)
          h.merge!(feature)
        else
          h[feature] = {} # steep:ignore
        end
      end

      features.merge(normalized_features) # steep:ignore
    end

    # Sets and normalizes features hash
    #
    # @param [Hash] features
    # @api private
    # @return [Hash]
    def features=(features)
      result = {} #: Hash[Symbol, Feature]
      @features = features.each_with_object(result) do |(name, opts_or_feature), h|
        h[name] = if opts_or_feature.is_a?(Feature)
                    opts_or_feature
                  else
                    unless (feature = self.class.available_features[name])
                      argument_error! "Unsupported feature: #{name}"
                    end
                    feature.new(**opts_or_feature) # steep:ignore
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
        if    !value                    then nil
        elsif true == value             then {} #: Hash[untyped, untyped]
        elsif value.respond_to?(:fetch) then value
        else argument_error! "Unsupported follow options: #{value}"
        end
    end

    def_option :retriable, reader_only: true

    # Sets retriable options
    #
    # @param [Boolean, Hash, nil] value
    # @api private
    # @return [Hash, nil]
    def retriable=(value)
      @retriable =
        if    !value                    then nil
        elsif true == value             then {} #: Hash[untyped, untyped]
        elsif value.respond_to?(:fetch) then value
        else argument_error! "Unsupported retriable options: #{value}"
        end
    end

    def_option :base_uri, reader_only: true

    # Sets the base URI for resolving relative request paths
    #
    # @param [String, HTTP::URI, nil] value
    # @api private
    # @return [HTTP::URI, nil]
    def base_uri=(value)
      @base_uri = value ? parse_base_uri(value) : nil
      validate_base_uri_and_persistent!
    end

    # Checks whether a base URI is set
    #
    # @example
    #   opts = HTTP::Options.new(base_uri: "https://example.com")
    #   opts.base_uri?
    #
    # @api public
    # @return [Boolean]
    def base_uri?
      !base_uri.nil?
    end

    def_option :persistent, reader_only: true

    # Sets persistent connection origin
    #
    # @param [String, nil] value
    # @api private
    # @return [String, nil]
    def persistent=(value)
      @persistent = value ? URI.parse(value).origin : nil
      validate_base_uri_and_persistent!
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

    private

    # Parses and validates a base URI value
    #
    # @param [String, HTTP::URI] value the base URI to parse
    # @api private
    # @return [HTTP::URI]
    def parse_base_uri(value)
      uri = URI.parse(value)

      base = @base_uri
      return resolve_base_uri(base, uri) if base

      argument_error!(format("Invalid base URI: %s", value)) unless uri.scheme
      uri
    end

    # Resolves a relative URI against an existing base URI
    #
    # @param [HTTP::URI] base the existing base URI
    # @param [HTTP::URI] relative the URI to join
    # @api private
    # @return [HTTP::URI]
    def resolve_base_uri(base, relative)
      unless base.path.end_with?("/")
        base = base.dup
        base.path = "#{base.path}/"
      end

      URI.parse(base.join(relative))
    end

    # Validates that base URI and persistent origin are compatible
    #
    # @api private
    # @return [void]
    def validate_base_uri_and_persistent!
      base = @base_uri
      persistent = @persistent
      return unless base && persistent
      return if base.origin == persistent

      argument_error!(
        format("Persistence origin (%s) conflicts with base URI origin (%s)",
               persistent, base.origin)
      )
    end
  end
end
