# frozen_string_literal: true

require "test_helper"

class HTTPOptionsNewTest < Minitest::Test
  cover "HTTP::Options*"

  def test_supports_a_options_instance
    opts = HTTP::Options.new

    assert_equal opts, HTTP::Options.new(opts)
  end

  def test_with_a_hash_coerces_response_correctly
    opts = HTTP::Options.new(response: :object)

    assert_equal :object, opts.response
  end

  def test_with_a_hash_coerces_headers_correctly
    opts = HTTP::Options.new(headers: { accept: "json" })

    assert_equal [%w[Accept json]], opts.headers.to_a
  end

  def test_with_a_hash_coerces_proxy_correctly
    opts = HTTP::Options.new(proxy: { proxy_address: "127.0.0.1", proxy_port: 8080 })

    assert_equal({ proxy_address: "127.0.0.1", proxy_port: 8080 }, opts.proxy)
  end

  def test_with_a_hash_coerces_form_correctly
    opts = HTTP::Options.new(form: { foo: 42 })

    assert_equal({ foo: 42 }, opts.form)
  end
end
