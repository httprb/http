# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "headers" do
  let(:opts) { HTTP::Options.new }

  it "defaults to be empty" do
    assert_empty opts.headers
  end

  it "may be specified with with_headers" do
    opts2 = opts.with_headers(accept: "json")

    assert_empty opts.headers
    assert_equal [%w[Accept json]], opts2.headers.to_a
  end

  it "accepts any object that respond to :to_hash" do
    x = if RUBY_VERSION >= "3.2.0"
          Data.define(:to_hash).new(to_hash: { "accept" => "json" })
        else
          Struct.new(:to_hash).new({ "accept" => "json" })
        end

    assert_equal "json", opts.with_headers(x).headers["accept"]
  end
end
