# frozen_string_literal: true

require "test_helper"

class HTTPOptionsProxyTest < Minitest::Test
  cover "HTTP::Options*"

  def test_defaults_to_empty_hash
    opts = HTTP::Options.new

    assert_equal({}, opts.proxy)
  end

  def test_may_be_specified_with_with_proxy
    opts = HTTP::Options.new
    opts2 = opts.with_proxy(proxy_address: "127.0.0.1", proxy_port: 8080)

    assert_equal({}, opts.proxy)
    assert_equal({ proxy_address: "127.0.0.1", proxy_port: 8080 }, opts2.proxy)
  end

  def test_accepts_proxy_address_port_username_and_password
    opts = HTTP::Options.new
    opts2 = opts.with_proxy(proxy_address: "127.0.0.1", proxy_port: 8080, proxy_username: "username",
                            proxy_password: "password")

    assert_equal(
      { proxy_address: "127.0.0.1", proxy_port: 8080, proxy_username: "username",
proxy_password: "password" }, opts2.proxy
    )
  end
end
