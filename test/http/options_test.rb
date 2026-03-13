# frozen_string_literal: true

require "test_helper"

describe HTTP::Options do
  cover "HTTP::Options*"
  let(:opts) { HTTP::Options.new }

  describe ".new" do
    it "returns the same instance when given an Options object" do
      original = HTTP::Options.new
      result = HTTP::Options.new(original)

      assert_same original, result
    end

    it "does not treat a hash as an Options instance" do
      result = HTTP::Options.new(response: :body)

      assert_instance_of HTTP::Options, result
    end

    it "creates from a hash argument" do
      result = HTTP::Options.new(response: :body)

      assert_equal :body, result.response
    end

    it "creates from keyword arguments" do
      result = HTTP::Options.new(response: :object)

      assert_equal :object, result.response
    end

    it "prefers positional hash over kwargs" do
      result = HTTP::Options.new({ response: :body })

      assert_equal :body, result.response
    end
  end

  describe ".defined_options" do
    it "returns an array" do
      assert_kind_of Array, HTTP::Options.defined_options
    end

    it "contains all expected option names as symbols" do
      expected = %i[
        headers encoding features proxy params form json body response
        socket_class nodelay ssl_socket_class ssl_context ssl
        keep_alive_timeout timeout_class timeout_options
        follow retriable base_uri persistent
      ]

      expected.each do |name|
        assert_includes HTTP::Options.defined_options, name
      end
    end
  end

  describe ".register_feature" do
    it "stores the feature implementation by name" do
      fake_feature = Class.new(HTTP::Feature)
      HTTP::Options.register_feature(:test_feature_register, fake_feature)

      assert_equal fake_feature, HTTP::Options.available_features[:test_feature_register]
    ensure
      HTTP::Options.available_features.delete(:test_feature_register)
    end
  end

  describe "#initialize defaults" do
    it "defaults response to :auto" do
      assert_equal :auto, opts.response
    end

    it "defaults keep_alive_timeout to 5" do
      assert_equal 5, opts.keep_alive_timeout
    end

    it "defaults nodelay to false" do
      refute opts.nodelay
    end

    it "defaults headers to empty" do
      assert_empty opts.headers
    end

    it "defaults ssl to empty hash" do
      assert_equal({}, opts.ssl)
    end

    it "defaults timeout_options to empty hash" do
      assert_equal({}, opts.timeout_options)
    end

    it "defaults proxy to empty hash" do
      assert_equal({}, opts.proxy)
    end

    it "defaults features to empty hash" do
      assert_equal({}, opts.features)
    end

    it "defaults timeout_class to Timeout::Null" do
      assert_equal HTTP::Timeout::Null, opts.timeout_class
    end

    it "defaults socket_class to TCPSocket" do
      assert_equal TCPSocket, opts.socket_class
    end

    it "defaults ssl_socket_class to OpenSSL::SSL::SSLSocket" do
      assert_equal OpenSSL::SSL::SSLSocket, opts.ssl_socket_class
    end

    it "defaults encoding to nil" do
      assert_nil opts.encoding
    end

    it "defaults params to nil" do
      assert_nil opts.params
    end

    it "defaults form to nil" do
      assert_nil opts.form
    end

    it "defaults json to nil" do
      assert_nil opts.json
    end

    it "defaults body to nil" do
      assert_nil opts.body
    end

    it "defaults follow to nil" do
      assert_nil opts.follow
    end

    it "defaults retriable to nil" do
      assert_nil opts.retriable
    end

    it "defaults base_uri to nil" do
      assert_nil opts.base_uri
    end

    it "defaults persistent to nil" do
      assert_nil opts.persistent
    end

    it "defaults ssl_context to nil" do
      assert_nil opts.ssl_context
    end
  end

  describe "#to_hash" do
    it "contains all defined options" do
      hash = opts.to_hash

      HTTP::Options.defined_options.each do |name|
        assert_includes hash.keys, name
      end
    end

    it "returns correct values for custom options" do
      custom = HTTP::Options.new(response: :body, keep_alive_timeout: 10)
      hash = custom.to_hash

      assert_equal :body, hash[:response]
      assert_equal 10, hash[:keep_alive_timeout]
    end
  end

  describe "#merge" do
    it "merges headers by combining them" do
      opts1 = HTTP::Options.new(headers: { foo: "bar" })
      opts2 = HTTP::Options.new(headers: { baz: "qux" })
      merged = opts1.merge(opts2)

      assert_equal "bar", merged.headers["Foo"]
      assert_equal "qux", merged.headers["Baz"]
    end

    it "replaces non-header values" do
      opts1 = HTTP::Options.new(response: :auto)
      merged = opts1.merge(response: :body)

      assert_equal :body, merged.response
    end
  end

  describe "#dup" do
    it "returns a duplicate" do
      dupped = opts.dup

      assert_equal :auto, dupped.response
    end

    it "yields the duplicate when a block is given" do
      yielded = nil
      dupped = opts.dup { |d| yielded = d }

      assert_same dupped, yielded
    end
  end

  describe "#feature" do
    it "returns nil for unregistered feature" do
      assert_nil opts.feature(:nonexistent)
    end

    it "returns the feature instance for a registered feature" do
      opts_with = opts.with_features([:auto_inflate])

      assert_instance_of HTTP::Features::AutoInflate, opts_with.feature(:auto_inflate)
    end
  end

  describe "#with_follow" do
    it "sets follow to empty hash when true" do
      result = opts.with_follow(true)

      assert_equal({}, result.follow)
    end

    it "sets follow to nil when false" do
      result = opts.with_follow(false)

      assert_nil result.follow
    end

    it "sets follow to nil when nil" do
      result = opts.with_follow(nil)

      assert_nil result.follow
    end

    it "passes through hash options" do
      result = opts.with_follow(max_hops: 5)

      assert_equal({ max_hops: 5 }, result.follow)
    end

    it "raises error for unsupported follow value" do
      err = assert_raises(HTTP::Error) { opts.with_follow(42) }

      assert_match(/Unsupported follow/, err.message)
      assert_includes err.message, "42"
    end

    it "does not modify original" do
      opts.with_follow(true)

      assert_nil opts.follow
    end
  end

  describe "#with_retriable" do
    it "sets retriable to empty hash when true" do
      result = opts.with_retriable(true)

      assert_equal({}, result.retriable)
    end

    it "sets retriable to nil when false" do
      result = opts.with_retriable(false)

      assert_nil result.retriable
    end

    it "sets retriable to nil when nil" do
      result = opts.with_retriable(nil)

      assert_nil result.retriable
    end

    it "passes through hash options" do
      result = opts.with_retriable(max_retries: 3)

      assert_equal({ max_retries: 3 }, result.retriable)
    end

    it "raises error for unsupported retriable value" do
      err = assert_raises(HTTP::Error) { opts.with_retriable(42) }

      assert_match(/Unsupported retriable/, err.message)
      assert_includes err.message, "42"
    end

    it "does not modify original" do
      opts.with_retriable(true)

      assert_nil opts.retriable
    end
  end

  describe "#persistent?" do
    it "returns false by default" do
      refute_predicate opts, :persistent?
    end

    it "returns true when persistent is set" do
      result = opts.with_persistent("https://example.com")

      assert_predicate result, :persistent?
    end
  end

  describe "#with_persistent" do
    it "sets persistent to origin" do
      result = opts.with_persistent("https://example.com/path")

      assert_equal "https://example.com", result.persistent
    end

    it "clears persistent when set to nil" do
      with_persistent = opts.with_persistent("https://example.com")
      result = with_persistent.with_persistent(nil)

      assert_nil result.persistent
    end
  end

  describe "#with_encoding" do
    it "finds encoding by name" do
      result = opts.with_encoding("UTF-8")

      assert_equal Encoding::UTF_8, result.encoding
    end
  end

  describe "#features=" do
    it "accepts pre-built Feature instances" do
      feature_instance = HTTP::Features::AutoInflate.new
      result = HTTP::Options.new(features: { auto_inflate: feature_instance })

      assert_same feature_instance, result.features[:auto_inflate]
    end

    it "raises for unsupported feature names" do
      err = assert_raises(HTTP::Error) { HTTP::Options.new(features: { bogus: {} }) }

      assert_equal "Unsupported feature: bogus", err.message
    end
  end

  describe "with_ methods for simple options" do
    it "with_proxy returns new options with updated proxy" do
      result = opts.with_proxy(proxy_address: "127.0.0.1")

      assert_equal({ proxy_address: "127.0.0.1" }, result.proxy)
      assert_equal({}, opts.proxy)
    end

    it "with_params returns new options with updated params" do
      result = opts.with_params(foo: "bar")

      assert_equal({ foo: "bar" }, result.params)
      assert_nil opts.params
    end

    it "with_form returns new options with updated form" do
      result = opts.with_form(foo: 42)

      assert_equal({ foo: 42 }, result.form)
      assert_nil opts.form
    end

    it "with_json returns new options with updated json" do
      result = opts.with_json(foo: 42)

      assert_equal({ foo: 42 }, result.json)
      assert_nil opts.json
    end

    it "with_body returns new options with updated body" do
      result = opts.with_body("data")

      assert_equal "data", result.body
      assert_nil opts.body
    end

    it "with_response returns new options with updated response" do
      result = opts.with_response(:body)

      assert_equal :body, result.response
      assert_equal :auto, opts.response
    end

    it "with_socket_class returns new options" do
      custom_class = Class.new
      result = opts.with_socket_class(custom_class)

      assert_equal custom_class, result.socket_class
    end

    it "with_nodelay returns new options" do
      result = opts.with_nodelay(true)

      assert result.nodelay
    end

    it "with_ssl_socket_class returns new options" do
      custom_class = Class.new
      result = opts.with_ssl_socket_class(custom_class)

      assert_equal custom_class, result.ssl_socket_class
    end

    it "with_ssl_context returns new options" do
      ctx = OpenSSL::SSL::SSLContext.new
      result = opts.with_ssl_context(ctx)

      assert_equal ctx, result.ssl_context
    end

    it "with_ssl returns new options" do
      result = opts.with_ssl(verify_mode: OpenSSL::SSL::VERIFY_NONE)

      assert_equal({ verify_mode: OpenSSL::SSL::VERIFY_NONE }, result.ssl)
    end

    it "with_keep_alive_timeout returns new options" do
      result = opts.with_keep_alive_timeout(10)

      assert_equal 10, result.keep_alive_timeout
    end

    it "with_timeout_class returns new options" do
      custom_class = Class.new
      result = opts.with_timeout_class(custom_class)

      assert_equal custom_class, result.timeout_class
    end

    it "with_timeout_options returns new options" do
      result = opts.with_timeout_options(read_timeout: 5)

      assert_equal({ read_timeout: 5 }, result.timeout_options)
    end
  end

  describe "#argument_error! backtrace" do
    it "excludes argument_error! from the backtrace" do
      err = assert_raises(HTTP::Error) { opts.with_follow(42) }

      refute err.backtrace.any? { |line| line.include?("argument_error!") },
             "backtrace should not include argument_error! method"
    end

    it "starts the backtrace at the calling setter method" do
      err = assert_raises(HTTP::Error) { opts.with_follow(42) }

      assert_includes err.backtrace.first, "definitions.rb"
    end

    it "includes more than one backtrace frame" do
      err = assert_raises(HTTP::Error) { opts.with_follow(42) }

      assert_operator err.backtrace.length, :>, 1
    end

    it "preserves the full backtrace down to the bottom of the stack" do
      ref_err = begin; raise HTTP::Error, "ref"; rescue HTTP::Error => e; e; end
      arg_err = assert_raises(HTTP::Error) { opts.with_follow(42) }

      assert_equal ref_err.backtrace.last, arg_err.backtrace.last
    end
  end

  describe "non-reader_only options have protected writers" do
    it "response= is protected" do
      assert_raises(NoMethodError) { opts.response = :body }
    end

    it "proxy= is protected" do
      assert_raises(NoMethodError) { opts.proxy = {} }
    end

    it "keep_alive_timeout= is protected" do
      assert_raises(NoMethodError) { opts.keep_alive_timeout = 10 }
    end
  end
end
