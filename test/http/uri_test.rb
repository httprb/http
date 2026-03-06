# frozen_string_literal: true

require "test_helper"

describe HTTP::URI do
  let(:example_ipv6_address) { "2606:2800:220:1:248:1893:25c8:1946" }

  let(:example_http_uri_string)  { "http://example.com" }
  let(:example_https_uri_string) { "https://example.com" }
  let(:example_ipv6_uri_string) { "https://[#{example_ipv6_address}]" }

  let(:http_uri)  { HTTP::URI.parse(example_http_uri_string) }
  let(:https_uri) { HTTP::URI.parse(example_https_uri_string) }
  let(:ipv6_uri)  { HTTP::URI.parse(example_ipv6_uri_string) }

  it "knows URI schemes" do
    assert_equal "http", http_uri.scheme
    assert_equal "https", https_uri.scheme
  end

  it "sets default ports for HTTP URIs" do
    assert_equal 80, http_uri.port
  end

  it "sets default ports for HTTPS URIs" do
    assert_equal 443, https_uri.port
  end

  describe "#host" do
    it "strips brackets from IPv6 addresses" do
      assert_equal "2606:2800:220:1:248:1893:25c8:1946", ipv6_uri.host
    end
  end

  describe "#normalized_host" do
    it "strips brackets from IPv6 addresses" do
      assert_equal "2606:2800:220:1:248:1893:25c8:1946", ipv6_uri.normalized_host
    end
  end

  describe "#inspect" do
    it "returns a human-readable representation" do
      assert_match(%r{#<HTTP::URI:0x\h+ URI:http://example\.com>}, http_uri.inspect)
    end
  end

  describe "#host=" do
    it "updates cached values for #host and #normalized_host" do
      assert_equal "example.com", http_uri.host
      assert_equal "example.com", http_uri.normalized_host

      http_uri.host = "[#{example_ipv6_address}]"

      assert_equal example_ipv6_address, http_uri.host
      assert_equal example_ipv6_address, http_uri.normalized_host
    end

    it "ensures IPv6 addresses are bracketed in the inner Addressable::URI" do
      assert_equal "example.com", http_uri.host
      assert_equal "example.com", http_uri.normalized_host

      http_uri.host = example_ipv6_address

      assert_equal example_ipv6_address, http_uri.host
      assert_equal example_ipv6_address, http_uri.normalized_host
      assert_equal "[#{example_ipv6_address}]", http_uri.instance_variable_get(:@uri).host
    end
  end

  describe ".form_encode" do
    it "encodes key/value pairs" do
      assert_equal "foo=bar&baz=quux", HTTP::URI.form_encode(foo: "bar", baz: "quux")
    end
  end

  describe "#initialize" do
    it "raises TypeError for invalid argument" do
      err = assert_raises(TypeError) { HTTP::URI.new(42) }
      assert_match(/expected Hash/, err.message)
    end
  end

  describe "#http?" do
    it "returns true for HTTP URIs" do
      assert_predicate http_uri, :http?
    end

    it "returns false for HTTPS URIs" do
      refute_predicate https_uri, :http?
    end
  end

  describe "#eql?" do
    it "returns true for equivalent URIs" do
      assert http_uri.eql?(HTTP::URI.parse(example_http_uri_string))
    end

    it "returns false for non-URI objects" do
      refute http_uri.eql?("http://example.com")
    end
  end

  describe "#hash" do
    it "returns an Integer" do
      assert_kind_of Integer, http_uri.hash
    end
  end

  describe "#dup" do
    it "doesn't share internal value between duplicates" do
      duplicated_uri = http_uri.dup
      duplicated_uri.host = "example.org"

      assert_equal "http://example.org", duplicated_uri.to_s
      assert_equal "http://example.com", http_uri.to_s
    end
  end
end
