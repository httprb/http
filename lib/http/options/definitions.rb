# frozen_string_literal: true

module HTTP
  # Configuration options for HTTP requests and clients
  class Options
    def_option :headers do |new_headers|
      headers.merge(new_headers) # steep:ignore
    end

    def_option :cookies do |new_cookies|
      new_cookies.each_with_object cookies.dup do |(k, v), jar| # steep:ignore
        cookie = k.is_a?(Cookie) ? k : Cookie.new(k.to_s, v.to_s)
        jar[cookie.name] = cookie.cookie_value
      end
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
          h[feature] = Hash[]
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
        elsif true == value             then Hash[]
        elsif value.respond_to?(:fetch) then value
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
  end
end
