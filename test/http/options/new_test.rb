# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "new" do
  cover "HTTP::Options*"
  it "supports a Options instance" do
    opts = HTTP::Options.new

    assert_equal opts, HTTP::Options.new(opts)
  end

  context "with a Hash" do
    it "coerces :response correctly" do
      opts = HTTP::Options.new(response: :object)

      assert_equal :object, opts.response
    end

    it "coerces :headers correctly" do
      opts = HTTP::Options.new(headers: { accept: "json" })

      assert_equal [%w[Accept json]], opts.headers.to_a
    end

    it "coerces :proxy correctly" do
      opts = HTTP::Options.new(proxy: { proxy_address: "127.0.0.1", proxy_port: 8080 })

      assert_equal({ proxy_address: "127.0.0.1", proxy_port: 8080 }, opts.proxy)
    end

    it "coerces :form correctly" do
      opts = HTTP::Options.new(form: { foo: 42 })

      assert_equal({ foo: 42 }, opts.form)
    end
  end
end
