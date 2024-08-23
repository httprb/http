# frozen_string_literal: true

RSpec.describe HTTP::HeaderNormalizer do
  subject(:normalizer) { described_class.new }

  describe "#normalize" do
    it "normalizes the header" do
      expect(normalizer.normalize("content_type")).to eq "Content-Type"
    end

    it "caches normalized headers" do
      object_id = normalizer.normalize("content_type").object_id
      expect(object_id).to eq normalizer.normalize("content_type").object_id
    end

    it "only caches up to MAX_CACHE_SIZE headers" do
      (1..described_class::MAX_CACHE_SIZE + 1).each do |i|
        normalizer.normalize("header#{i}")
      end

      expect(normalizer.instance_variable_get(:@cache).size).to eq described_class::MAX_CACHE_SIZE
    end
  end
end
