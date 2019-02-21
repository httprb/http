# frozen_string_literal: true

module HTTP
  module Features
    class UriNormalizer < Feature
      attr_reader :custom_uri_normalizer

      def initialize(custom_uri_normalizer: DefaultUriNormalizer.new)
        @custom_uri_normalizer = custom_uri_normalizer
      end

      def normalize_uri(uri)
        custom_uri_normalizer.normalize_uri(uri)
      end

      class DefaultUriNormalizer
        def normalize_uri(uri)
          uri = HTTP::URI.parse uri
          HTTP::URI.new(
            :scheme     => uri.normalized_scheme,
            :authority  => uri.normalized_authority,
            :path       => uri.normalized_path,
            :query      => uri.query,
            :fragment   => uri.normalized_fragment
          )
        end
      end

      HTTP::Options.register_feature(:uri_normalizer, self)
    end
  end
end
