# frozen_string_literal: true

require "test_helper"

class HTTPOptionsHeadersTest < Minitest::Test
  cover "HTTP::Options*"

  def test_defaults_to_be_empty
    opts = HTTP::Options.new

    assert_empty opts.headers
  end

  def test_may_be_specified_with_with_headers
    opts = HTTP::Options.new
    opts2 = opts.with_headers(accept: "json")

    assert_empty opts.headers
    assert_equal [%w[Accept json]], opts2.headers.to_a
  end

  def test_accepts_any_object_that_respond_to_to_hash
    opts = HTTP::Options.new
    x = if RUBY_VERSION >= "3.2.0"
          Data.define(:to_hash).new(to_hash: { "accept" => "json" })
        else
          Struct.new(:to_hash).new({ "accept" => "json" })
        end

    assert_equal "json", opts.with_headers(x).headers["accept"]
  end
end
