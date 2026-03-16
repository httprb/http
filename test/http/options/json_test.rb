# frozen_string_literal: true

require "test_helper"

class HTTPOptionsJSONTest < Minitest::Test
  cover "HTTP::Options*"

  def test_defaults_to_nil
    opts = HTTP::Options.new

    assert_nil opts.json
  end

  def test_may_be_specified_with_with_json_data
    opts = HTTP::Options.new
    opts2 = opts.with_json(foo: 42)

    assert_nil opts.json
    assert_equal({ foo: 42 }, opts2.json)
  end
end
