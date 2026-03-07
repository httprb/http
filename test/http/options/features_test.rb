# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "features" do
  cover "HTTP::Options*"
  let(:opts) { HTTP::Options.new }

  it "defaults to be empty" do
    assert_empty opts.features
  end

  it "accepts plain symbols in array" do
    opts2 = opts.with_features([:auto_inflate])

    assert_empty opts.features
    assert_equal [:auto_inflate], opts2.features.keys
    assert_instance_of HTTP::Features::AutoInflate, opts2.features[:auto_inflate]
  end

  it "accepts feature name with its options in array" do
    opts2 = opts.with_features([{ auto_deflate: { method: :deflate } }])

    assert_empty opts.features
    assert_equal [:auto_deflate], opts2.features.keys
    assert_instance_of HTTP::Features::AutoDeflate, opts2.features[:auto_deflate]
    assert_equal "deflate", opts2.features[:auto_deflate].method
  end

  it "raises error for not supported features" do
    error = assert_raises(HTTP::Error) { opts.with_features([:wrong_feature]) }
    assert_equal "Unsupported feature: wrong_feature", error.message
  end
end
