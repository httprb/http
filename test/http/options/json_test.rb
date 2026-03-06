# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "json" do
  let(:opts) { HTTP::Options.new }

  it "defaults to nil" do
    assert_nil opts.json
  end

  it "may be specified with with_json data" do
    opts2 = opts.with_json(foo: 42)

    assert_nil opts.json
    assert_equal({ foo: 42 }, opts2.json)
  end
end
