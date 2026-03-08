# frozen_string_literal: true

require "test_helper"
require "base64"

describe HTTP::Base64 do
  cover "HTTP::Base64*"

  let(:encoder) do
    klass = Class.new { include HTTP::Base64 }
    klass.new
  end

  describe "#encode64" do
    it "encodes a string using strict Base64 (no newlines)" do
      assert_equal "aGVsbG8=", encoder.send(:encode64, "hello")
    end

    it "produces output decodable by standard Base64" do
      input = "user:password"

      assert_equal input, Base64.strict_decode64(encoder.send(:encode64, input))
    end

    it "encodes empty string" do
      assert_equal "", encoder.send(:encode64, "")
    end
  end
end
