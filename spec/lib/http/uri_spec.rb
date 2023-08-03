# frozen_string_literal: true

RSpec.describe HTTP::URI do
  let(:example_ipv6_address) { "2606:2800:220:1:248:1893:25c8:1946" }

  let(:example_http_uri_string)  { "http://example.com" }
  let(:example_https_uri_string) { "https://example.com" }
  let(:example_ipv6_uri_string) { "https://[#{example_ipv6_address}]" }

  subject(:http_uri)  { described_class.parse(example_http_uri_string) }
  subject(:https_uri) { described_class.parse(example_https_uri_string) }
  subject(:ipv6_uri) { described_class.parse(example_ipv6_uri_string) }

  describe "NORMALIZER" do
    it "lower-cases scheme" do
      expect(HTTP::URI::NORMALIZER.call("HttP://example.com").scheme).to eq "http"
    end

    it "lower-cases hostname" do
      expect(HTTP::URI::NORMALIZER.call("http://EXAMPLE.com").host).to eq "example.com"
    end

    it "decodes percent-encoded hostname" do
      expect(HTTP::URI::NORMALIZER.call("http://ex%61mple.com").host).to eq "example.com"
    end

    it "removes trailing period in hostname" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com.").host).to eq "example.com"
    end

    it "IDN-encodes non-ASCII hostname" do
      expect(HTTP::URI::NORMALIZER.call("http://exämple.com").host).to eq "xn--exmple-cua.com"
    end

    it "ensures path is not empty" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com").path).to eq "/"
    end

    it "preserves double slashes in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com//a///b").path).to eq "//a///b"
    end

    it "resolves single-dot segments in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/a/./b").path).to eq "/a/b"
    end

    it "resolves double-dot segments in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/a/b/../c").path).to eq "/a/c"
    end

    it "resolves leading double-dot segments in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/../a/b").path).to eq "/a/b"
    end

    it "percent-encodes control characters in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/\x00\x7F\n").path).to eq "/%00%7F%0A"
    end

    it "percent-encodes space in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/a b").path).to eq "/a%20b"
    end

    it "percent-encodes non-ASCII characters in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/キョ").path).to eq "/%E3%82%AD%E3%83%A7"
    end

    it "does not percent-encode non-special characters in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/~.-_!$&()*,;=:@{}").path).to eq "/~.-_!$&()*,;=:@{}"
    end

    it "preserves escape sequences in path" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/%41").path).to eq "/%41"
    end

    it "allows no query" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com").query).to be_nil
    end

    it "percent-encodes control characters in query" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/?\x00\x7F\n").query).to eq "%00%7F%0A"
    end

    it "percent-encodes space in query" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/?a b").query).to eq "a%20b"
    end

    it "percent-encodes non-ASCII characters in query" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com?キョ").query).to eq "%E3%82%AD%E3%83%A7"
    end

    it "does not percent-encode non-special characters in query" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/?~.-_!$&()*,;=:@{}?").query).to eq "~.-_!$&()*,;=:@{}?"
    end

    it "preserves escape sequences in query" do
      expect(HTTP::URI::NORMALIZER.call("http://example.com/?%41").query).to eq "%41"
    end
  end

  it "knows URI schemes" do
    expect(http_uri.scheme).to eq "http"
    expect(https_uri.scheme).to eq "https"
  end

  it "sets default ports for HTTP URIs" do
    expect(http_uri.port).to eq 80
  end

  it "sets default ports for HTTPS URIs" do
    expect(https_uri.port).to eq 443
  end

  describe "#host" do
    it "strips brackets from IPv6 addresses" do
      expect(ipv6_uri.host).to eq("2606:2800:220:1:248:1893:25c8:1946")
    end
  end

  describe "#normalized_host" do
    it "strips brackets from IPv6 addresses" do
      expect(ipv6_uri.normalized_host).to eq("2606:2800:220:1:248:1893:25c8:1946")
    end
  end

  describe "#host=" do
    it "updates cached values for #host and #normalized_host" do
      expect(http_uri.host).to eq("example.com")
      expect(http_uri.normalized_host).to eq("example.com")

      http_uri.host = "[#{example_ipv6_address}]"

      expect(http_uri.host).to eq(example_ipv6_address)
      expect(http_uri.normalized_host).to eq(example_ipv6_address)
    end

    it "ensures IPv6 addresses are bracketed in the inner Addressable::URI" do
      expect(http_uri.host).to eq("example.com")
      expect(http_uri.normalized_host).to eq("example.com")

      http_uri.host = example_ipv6_address

      expect(http_uri.host).to eq(example_ipv6_address)
      expect(http_uri.normalized_host).to eq(example_ipv6_address)
      expect(http_uri.instance_variable_get(:@uri).host).to eq("[#{example_ipv6_address}]")
    end
  end

  describe "#dup" do
    it "doesn't share internal value between duplicates" do
      duplicated_uri = http_uri.dup
      duplicated_uri.host = "example.org"

      expect(duplicated_uri.to_s).to eq("http://example.org")
      expect(http_uri.to_s).to eq("http://example.com")
    end
  end
end
