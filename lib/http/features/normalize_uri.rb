# frozen_string_literal: true

require "http/uri"

module HTTP
  module Features
    class NormalizeUri < Feature
      # The URI normalizer proc
      #
      # @example
      #   feature.normalizer
      #
      # @return [#call] the URI normalizer proc
      # @api public
      attr_reader :normalizer

      # Initializes the NormalizeUri feature
      #
      # @example
      #   NormalizeUri.new(normalizer: HTTP::URI::NORMALIZER)
      #
      # @param normalizer [#call] URI normalizer
      # @return [NormalizeUri]
      # @api public
      def initialize(normalizer: HTTP::URI::NORMALIZER)
        super()
        @normalizer = normalizer
      end

      HTTP::Options.register_feature(:normalize_uri, self)
    end
  end
end
