# frozen_string_literal: true

require "test_helper"

describe HTTP::Options do
  cover "HTTP::Options*"
  let(:subject_under_test) { HTTP::Options.new(response: :body) }

  it "has reader methods for attributes" do
    assert_equal :body, subject_under_test.response
  end

  it "coerces to a Hash" do
    assert_kind_of Hash, subject_under_test.to_hash
  end

  describe "#with_encoding" do
    it "finds encoding by name" do
      opts = subject_under_test.with_encoding("UTF-8")

      assert_equal Encoding::UTF_8, opts.encoding
    end
  end

  describe "#with_follow" do
    it "raises error for unsupported follow options" do
      err = assert_raises(HTTP::Error) { subject_under_test.with_follow(42) }
      assert_match(/Unsupported follow/, err.message)
    end
  end

  describe "#dup" do
    it "returns a duplicate without a block" do
      dupped = subject_under_test.dup

      assert_equal :body, dupped.response
    end
  end
end
