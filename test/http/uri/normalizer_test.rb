# frozen_string_literal: true

require "test_helper"

describe HTTP::URI::NORMALIZER do
  describe "scheme" do
    it "lower-cases scheme" do
      assert_equal "http", HTTP::URI::NORMALIZER.call("HttP://example.com").scheme
    end
  end

  describe "hostname" do
    it "lower-cases hostname" do
      assert_equal "example.com", HTTP::URI::NORMALIZER.call("http://EXAMPLE.com").host
    end

    it "decodes percent-encoded hostname" do
      assert_equal "example.com", HTTP::URI::NORMALIZER.call("http://ex%61mple.com").host
    end

    it "removes trailing period in hostname" do
      assert_equal "example.com", HTTP::URI::NORMALIZER.call("http://example.com.").host
    end

    it "IDN-encodes non-ASCII hostname" do
      assert_equal "xn--exmple-cua.com", HTTP::URI::NORMALIZER.call("http://ex\u00E4mple.com").host
    end
  end

  describe "path" do
    it "ensures path is not empty" do
      assert_equal "/", HTTP::URI::NORMALIZER.call("http://example.com").path
    end

    it "preserves double slashes in path" do
      assert_equal "//a///b", HTTP::URI::NORMALIZER.call("http://example.com//a///b").path
    end

    it "resolves single-dot segments in path" do
      assert_equal "/a/b", HTTP::URI::NORMALIZER.call("http://example.com/a/./b").path
    end

    it "resolves double-dot segments in path" do
      assert_equal "/a/c", HTTP::URI::NORMALIZER.call("http://example.com/a/b/../c").path
    end

    it "resolves leading double-dot segments in path" do
      assert_equal "/a/b", HTTP::URI::NORMALIZER.call("http://example.com/../a/b").path
    end

    it "percent-encodes control characters in path" do
      assert_equal "/%00%7F%0A", HTTP::URI::NORMALIZER.call("http://example.com/\x00\x7F\n").path
    end

    it "percent-encodes space in path" do
      assert_equal "/a%20b", HTTP::URI::NORMALIZER.call("http://example.com/a b").path
    end

    it "percent-encodes non-ASCII characters in path" do
      assert_equal "/%E3%82%AD%E3%83%A7", HTTP::URI::NORMALIZER.call("http://example.com/\u30AD\u30E7").path
    end

    it "does not percent-encode non-special characters in path" do
      assert_equal "/~.-_!$&()*,;=:@{}", HTTP::URI::NORMALIZER.call("http://example.com/~.-_!$&()*,;=:@{}").path
    end

    it "preserves escape sequences in path" do
      assert_equal "/%41", HTTP::URI::NORMALIZER.call("http://example.com/%41").path
    end
  end

  describe "query" do
    it "allows no query" do
      assert_nil HTTP::URI::NORMALIZER.call("http://example.com").query
    end

    it "percent-encodes control characters in query" do
      assert_equal "%00%7F%0A", HTTP::URI::NORMALIZER.call("http://example.com/?\x00\x7F\n").query
    end

    it "percent-encodes space in query" do
      assert_equal "a%20b", HTTP::URI::NORMALIZER.call("http://example.com/?a b").query
    end

    it "percent-encodes non-ASCII characters in query" do
      assert_equal "%E3%82%AD%E3%83%A7", HTTP::URI::NORMALIZER.call("http://example.com?\u30AD\u30E7").query
    end

    it "does not percent-encode non-special characters in query" do
      assert_equal "~.-_!$&()*,;=:@{}?", HTTP::URI::NORMALIZER.call("http://example.com/?~.-_!$&()*,;=:@{}?").query
    end

    it "preserves escape sequences in query" do
      assert_equal "%41", HTTP::URI::NORMALIZER.call("http://example.com/?%41").query
    end
  end
end
