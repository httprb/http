# frozen_string_literal: true

require "test_helper"

describe HTTP::Options, "base_uri" do
  cover "HTTP::Options*"
  let(:opts) { HTTP::Options.new }

  describe "#with_base_uri" do
    it "sets base_uri from a string" do
      result = opts.with_base_uri("https://example.com/api")

      assert_equal "https://example.com/api", result.base_uri.to_s
    end

    it "sets base_uri from an HTTP::URI" do
      uri = HTTP::URI.parse("https://example.com/api")
      result = opts.with_base_uri(uri)

      assert_equal "https://example.com/api", result.base_uri.to_s
    end

    it "raises for URI without scheme" do
      err = assert_raises(HTTP::Error) { opts.with_base_uri("/users") }

      assert_includes err.message, "Invalid base URI"
      assert_includes err.message, "/users"
    end

    it "raises for protocol-relative URI" do
      err = assert_raises(HTTP::Error) { opts.with_base_uri("//example.com/users") }

      assert_includes err.message, "Invalid base URI"
      assert_includes err.message, "//example.com/users"
    end

    it "does not modify the original options" do
      opts.with_base_uri("https://example.com")

      refute_predicate opts, :base_uri?
    end
  end

  describe "#base_uri?" do
    it "returns false by default" do
      refute_predicate opts, :base_uri?
    end

    it "returns true when base_uri is set" do
      result = opts.with_base_uri("https://example.com")

      assert_predicate result, :base_uri?
    end
  end

  describe "chaining base URIs" do
    it "joins a relative path onto existing base URI" do
      result = opts.with_base_uri("https://example.com").with_base_uri("api/v1")

      assert_equal "https://example.com/api/v1", result.base_uri.to_s
    end

    it "joins an absolute path onto existing base URI" do
      result = opts.with_base_uri("https://example.com/api").with_base_uri("/v2")

      assert_equal "https://example.com/v2", result.base_uri.to_s
    end

    it "replaces with a full URI" do
      result = opts.with_base_uri("https://example.com/api").with_base_uri("https://other.com/v2")

      assert_equal "https://other.com/v2", result.base_uri.to_s
    end

    it "joins onto base URI with trailing slash" do
      result = opts.with_base_uri("https://example.com/api/").with_base_uri("v2")

      assert_equal "https://example.com/api/v2", result.base_uri.to_s
    end

    it "handles parent path traversal" do
      result = opts.with_base_uri("https://example.com/api/v1").with_base_uri("../v2")

      assert_equal "https://example.com/api/v2", result.base_uri.to_s
    end

    it "does not mutate the intermediate base URI when chaining" do
      intermediate = opts.with_base_uri("https://example.com/api")
      intermediate.with_base_uri("v2")

      assert_equal "https://example.com/api", intermediate.base_uri.to_s
    end
  end

  describe "persistent and base_uri interaction" do
    it "allows compatible persistent and base_uri" do
      result = opts.with_base_uri("https://example.com/api").with_persistent("https://example.com")

      assert_equal "https://example.com/api", result.base_uri.to_s
      assert_equal "https://example.com", result.persistent
    end

    it "raises when persistent origin conflicts with base_uri" do
      with_base = opts.with_base_uri("https://example.com/api")

      err = assert_raises(HTTP::Error) { with_base.with_persistent("https://other.com") }
      assert_includes err.message, "https://other.com"
      assert_includes err.message, "base URI origin (https://example.com)"
    end

    it "raises when base_uri origin conflicts with persistent" do
      with_persistent = opts.with_persistent("https://example.com")

      err = assert_raises(HTTP::Error) { with_persistent.with_base_uri("https://other.com/api") }
      assert_includes err.message, "https://example.com"
      assert_includes err.message, "base URI origin (https://other.com)"
    end

    it "allows setting both via constructor when origins match" do
      result = HTTP::Options.new(base_uri: "https://example.com/api", persistent: "https://example.com")

      assert_equal "https://example.com/api", result.base_uri.to_s
      assert_equal "https://example.com", result.persistent
    end

    it "raises via constructor when origins conflict" do
      assert_raises(HTTP::Error) do
        HTTP::Options.new(base_uri: "https://example.com/api", persistent: "https://other.com")
      end
    end
  end
end
