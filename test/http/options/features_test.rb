# frozen_string_literal: true

require "test_helper"

class HTTPOptionsFeaturesTest < Minitest::Test
  cover "HTTP::Options*"

  def test_defaults_to_be_empty
    opts = HTTP::Options.new

    assert_empty opts.features
  end

  def test_accepts_plain_symbols_in_array
    opts = HTTP::Options.new
    opts2 = opts.with_features([:auto_inflate])

    assert_empty opts.features
    assert_equal [:auto_inflate], opts2.features.keys
    assert_instance_of HTTP::Features::AutoInflate, opts2.features[:auto_inflate]
  end

  def test_accepts_feature_name_with_its_options_in_array
    opts = HTTP::Options.new
    opts2 = opts.with_features([{ auto_deflate: { method: :deflate } }])

    assert_empty opts.features
    assert_equal [:auto_deflate], opts2.features.keys
    assert_instance_of HTTP::Features::AutoDeflate, opts2.features[:auto_deflate]
    assert_equal "deflate", opts2.features[:auto_deflate].method
  end

  def test_raises_error_for_not_supported_features
    opts = HTTP::Options.new
    error = assert_raises(HTTP::Error) { opts.with_features([:wrong_feature]) }
    assert_equal "Unsupported feature: wrong_feature", error.message
  end
end
