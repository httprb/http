# frozen_string_literal: true

require "test_helper"

describe HTTP::MimeType::JSON do
  let(:adapter) { HTTP::MimeType::JSON.send(:new) }

  describe "#encode" do
    it "uses to_json when available" do
      assert_equal '{"foo":"bar"}', adapter.encode(foo: "bar")
    end

    it "falls back to JSON.dump for objects without to_json" do
      obj = Object.new
      obj.define_singleton_method(:respond_to?) do |method, *args|
        return false if method == :to_json

        super(method, *args)
      end

      assert_kind_of String, adapter.encode(obj)
    end
  end

  describe "#decode" do
    it "parses JSON strings" do
      assert_equal({ "foo" => "bar" }, adapter.decode('{"foo":"bar"}'))
    end
  end
end
