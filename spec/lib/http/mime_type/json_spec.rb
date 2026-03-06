# frozen_string_literal: true

RSpec.describe HTTP::MimeType::JSON do
  subject(:adapter) { described_class.send(:new) }

  describe "#encode" do
    it "uses to_json when available" do
      expect(adapter.encode(foo: "bar")).to eq '{"foo":"bar"}'
    end

    it "falls back to JSON.dump for objects without to_json" do
      obj = Object.new
      allow(obj).to receive(:respond_to?).and_call_original
      allow(obj).to receive(:respond_to?).with(:to_json).and_return(false)
      expect(adapter.encode(obj)).to be_a String
    end
  end

  describe "#decode" do
    it "parses JSON strings" do
      expect(adapter.decode('{"foo":"bar"}')).to eq("foo" => "bar")
    end
  end
end
