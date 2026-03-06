# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "body" do
  let(:opts) { HTTP::Options.new }

  it "defaults to nil" do
    assert_nil opts.body
  end

  it "may be specified with with_body" do
    opts2 = opts.with_body("foo")

    assert_nil opts.body
    assert_equal "foo", opts2.body
  end
end
