# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "form" do
  let(:opts) { HTTP::Options.new }

  it "defaults to nil" do
    assert_nil opts.form
  end

  it "may be specified with with_form_data" do
    opts2 = opts.with_form(foo: 42)

    assert_nil opts.form
    assert_equal({ foo: 42 }, opts2.form)
  end
end
