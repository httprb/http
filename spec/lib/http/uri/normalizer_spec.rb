# frozen_string_literal: true

RSpec.describe HTTP::URI::NORMALIZER do
  describe "scheme" do
    it "lower-cases scheme" do
      expect(HTTP::URI::NORMALIZER.call("HttP://example.com").scheme).to eq "http"
    end
  end

  describe "hostname" do
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
  end

  describe "path" do
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
  end

  describe "query" do
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
end
