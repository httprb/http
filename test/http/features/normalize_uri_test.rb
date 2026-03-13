# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::NormalizeUri do
  cover "HTTP::Features::NormalizeUri*"

  describe "#initialize" do
    it "defaults normalizer to HTTP::URI::NORMALIZER" do
      feature = HTTP::Features::NormalizeUri.new

      assert_same HTTP::URI::NORMALIZER, feature.normalizer
    end

    it "accepts a custom normalizer" do
      custom = ->(uri) { uri }
      feature = HTTP::Features::NormalizeUri.new(normalizer: custom)

      assert_same custom, feature.normalizer
    end

    it "is a Feature" do
      assert_kind_of HTTP::Feature, HTTP::Features::NormalizeUri.new
    end
  end

  describe "#normalizer" do
    it "returns the normalizer" do
      custom = ->(uri) { uri }
      feature = HTTP::Features::NormalizeUri.new(normalizer: custom)

      assert_same custom, feature.normalizer
    end
  end

  describe ".register_feature" do
    it "registers as :normalize_uri" do
      assert_equal HTTP::Features::NormalizeUri, HTTP::Options.available_features[:normalize_uri]
    end
  end
end
