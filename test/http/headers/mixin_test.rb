# frozen_string_literal: true

require "test_helper"

describe HTTP::Headers::Mixin do
  let :dummy_class do
    Class.new do
      include HTTP::Headers::Mixin

      def initialize(headers)
        @headers = headers
      end
    end
  end

  let(:headers) { HTTP::Headers.new }
  let(:dummy)   { dummy_class.new headers }

  describe "#headers" do
    it "returns @headers instance variable" do
      assert_same headers, dummy.headers
    end
  end

  describe "#[]" do
    it "proxies to headers#[]" do
      headers.set :accept, "text/plain"

      assert_equal "text/plain", dummy[:accept]
    end
  end

  describe "#[]=" do
    it "proxies to headers#[]=" do
      dummy[:accept] = "text/plain"

      assert_equal "text/plain", headers[:accept]
    end
  end
end
