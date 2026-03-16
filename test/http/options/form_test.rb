# frozen_string_literal: true

require "test_helper"

class HTTPOptionsFormTest < Minitest::Test
  cover "HTTP::Options*"

  def test_defaults_to_nil
    opts = HTTP::Options.new

    assert_nil opts.form
  end

  def test_may_be_specified_with_with_form_data
    opts = HTTP::Options.new
    opts2 = opts.with_form(foo: 42)

    assert_nil opts.form
    assert_equal({ foo: 42 }, opts2.form)
  end
end
