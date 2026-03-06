# frozen_string_literal: true

RSpec.describe HTTP::Options do
  subject { described_class.new(response: :body) }

  it "has reader methods for attributes" do
    expect(subject.response).to eq(:body)
  end

  it "coerces to a Hash" do
    expect(subject.to_hash).to be_a(Hash)
  end

  describe "#with_encoding" do
    it "finds encoding by name" do
      opts = subject.with_encoding("UTF-8")
      expect(opts.encoding).to eq Encoding::UTF_8
    end
  end

  describe "#with_follow" do
    it "raises error for unsupported follow options" do
      expect { subject.with_follow(42) }.to raise_error(HTTP::Error, /Unsupported follow/)
    end
  end

  describe "#dup" do
    it "returns a duplicate without a block" do
      dupped = subject.dup
      expect(dupped.response).to eq :body
    end
  end
end
