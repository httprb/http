# frozen_string_literal: true

module HTTP
  # URI normalization and dot-segment removal
  class URI
    # Default URI normalizer
    # @private
    NORMALIZER = lambda do |uri|
      uri = HTTP::URI.parse uri
      scheme = uri.scheme&.downcase
      host = uri.normalized_host
      host = "[#{host}]" if host&.include?(":")
      default_port = scheme == HTTPS_SCHEME ? 443 : 80

      HTTP::URI.new(
        scheme:   scheme,
        user:     uri.user,
        password: uri.password,
        host:     host,
        port:     (uri.port == default_port ? nil : uri.port),
        path:     uri.path.empty? ? "/" : percent_encode(remove_dot_segments(uri.path)),
        query:    percent_encode(uri.query),
        fragment: uri.fragment
      )
    end

    # Standalone dot segments that terminate the algorithm
    # @private
    DOT_SEGMENTS = %w[. ..].freeze

    # Matches "/." followed by "/" or end-of-string
    # @private
    SINGLE_DOT_SEGMENT = %r{\A/\.(?:/|\z)}

    # Matches "/.." followed by "/" or end-of-string
    # @private
    DOUBLE_DOT_SEGMENT = %r{\A/\.\.(?:/|\z)}

    # Matches the last segment in a path (everything after the final "/")
    # @private
    LAST_SEGMENT = %r{/[^/]*\z}

    # Matches the first path segment, with or without a leading "/"
    # @private
    FIRST_SEGMENT = %r{\A/?[^/]*}

    # Remove dot segments from a URI path per RFC 3986 Section 5.2.4
    #
    # @param [String] path URI path to normalize
    #
    # @api private
    # @return [String] path with dot segments removed
    def self.remove_dot_segments(path)
      input  = path.dup
      output = +""
      until input.empty?
        reduce_dot_segment(input, output) unless
          input.delete_prefix!("../") || input.delete_prefix!("./") ||
          input.sub!(SINGLE_DOT_SEGMENT, "/")
      end
      output
    end
    private_class_method :remove_dot_segments

    # Process a single dot-segment removal step per RFC 3986 Section 5.2.4
    #
    # @param [String] input remaining path input (mutated)
    # @param [String] output accumulated result (mutated)
    #
    # @api private
    # @return [void]
    private_class_method def self.reduce_dot_segment(input, output)
      if input.sub!(DOUBLE_DOT_SEGMENT, "/")
        output.sub!(LAST_SEGMENT, "")
      elsif DOT_SEGMENTS.include?(input)
        input.clear
      else
        output << input.slice!(FIRST_SEGMENT) # steep:ignore
      end
    end
  end
end
