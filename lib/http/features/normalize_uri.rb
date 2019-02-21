# frozen_string_literal: true

module HTTP
  module Features
    class NormalizeUri < Feature
      attr_reader :normalizer

      def initialize(normalizer: Normalizer)
        @normalizer = normalizer
      end

      def normalize_uri(uri)
        normalizer.call(uri)
      end

      module Normalizer
        def self.call(uri)
          HTTP::URI::NORMALIZER.call(uri)
        end
      end

      HTTP::Options.register_feature(:normalize_uri, self)
    end
  end
end
