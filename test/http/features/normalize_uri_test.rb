# frozen_string_literal: true

require "test_helper"

class HTTPFeaturesNormalizeURITest < Minitest::Test
  cover "HTTP::Features::NormalizeUri*"

  # -- #initialize --

  def test_initialize_defaults_normalizer_to_http_uri_normalizer
    feature = HTTP::Features::NormalizeUri.new

    assert_same HTTP::URI::NORMALIZER, feature.normalizer
  end

  def test_initialize_accepts_a_custom_normalizer
    custom = ->(uri) { uri }
    feature = HTTP::Features::NormalizeUri.new(normalizer: custom)

    assert_same custom, feature.normalizer
  end

  def test_initialize_is_a_feature
    assert_kind_of HTTP::Feature, HTTP::Features::NormalizeUri.new
  end

  # -- #normalizer --

  def test_normalizer_returns_the_normalizer
    custom = ->(uri) { uri }
    feature = HTTP::Features::NormalizeUri.new(normalizer: custom)

    assert_same custom, feature.normalizer
  end

  # -- .register_feature --

  def test_register_feature_registers_as_normalize_uri
    assert_equal HTTP::Features::NormalizeUri, HTTP::Options.available_features[:normalize_uri]
  end
end
