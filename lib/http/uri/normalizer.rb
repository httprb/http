# frozen_string_literal: true

module HTTP
  class URI # rubocop:disable Style/Documentation
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

    # Remove dot segments from a URI path per RFC 3986 Section 5.2.4
    #
    # @param [String] path URI path to normalize
    #
    # @api private
    # @return [String] path with dot segments removed
    def self.remove_dot_segments(path) # rubocop:disable Metrics/MethodLength
      input  = +path
      output = +""

      until input.empty?
        unless input.delete_prefix!("../") || input.delete_prefix!("./") ||
               input.sub!(%r{\A/\.(?:/|\z)}, "/")
          if input.sub!(%r{\A/\.\.(?:/|\z)}, "/")
            output.sub!(%r{/[^/]*\z}, "")
          elsif DOT_SEGMENTS.include?(input)
            break
          else
            output << input.slice!(%r{\A/?[^/]*}) # steep:ignore
          end
        end
      end

      output
    end
    private_class_method :remove_dot_segments
  end
end
