# frozen_string_literal: true

require "test_helper"

class HTTPOptionsBodyTest < Minitest::Test
  cover "HTTP::Options*"

  def test_defaults_to_nil
    opts = HTTP::Options.new

    assert_nil opts.body
  end

  def test_may_be_specified_with_with_body
    opts = HTTP::Options.new
    opts2 = opts.with_body("foo")

    assert_nil opts.body
    assert_equal "foo", opts2.body
  end
end
