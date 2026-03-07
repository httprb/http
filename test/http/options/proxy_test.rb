# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "proxy" do
  cover "HTTP::Options*"
  let(:opts) { HTTP::Options.new }

  it "defaults to {}" do
    assert_equal({}, opts.proxy)
  end

  it "may be specified with with_proxy" do
    opts2 = opts.with_proxy(proxy_address: "127.0.0.1", proxy_port: 8080)

    assert_equal({}, opts.proxy)
    assert_equal({ proxy_address: "127.0.0.1", proxy_port: 8080 }, opts2.proxy)
  end

  it "accepts proxy address, port, username, and password" do
    opts2 = opts.with_proxy(proxy_address: "127.0.0.1", proxy_port: 8080, proxy_username: "username",
                            proxy_password: "password")

    assert_equal(
      { proxy_address: "127.0.0.1", proxy_port: 8080, proxy_username: "username",
proxy_password: "password" }, opts2.proxy
    )
  end
end
