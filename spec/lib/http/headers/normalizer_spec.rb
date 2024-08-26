# frozen_string_literal: true

RSpec.describe HTTP::Headers::Normalizer do
  subject(:normalizer) { described_class.new }

  include_context RSpec::Memory

  describe "#call" do
    it "normalizes the header" do
      expect(normalizer.call("content_type")).to eq "Content-Type"
    end

    it "returns a non-frozen string" do
      expect(normalizer.call("content_type")).not_to be_frozen
    end

    it "evicts the oldest item when cache is full" do
      max_headers = (1..described_class::Cache::MAX_SIZE).map { |i| "Header#{i}" }
      max_headers.each { |header| normalizer.call(header) }
      normalizer.call("New-Header")
      cache_store = normalizer.instance_variable_get(:@cache).instance_variable_get(:@store)
      expect(cache_store.keys).to eq(max_headers[1..] + ["New-Header"])
    end

    describe "multiple invocations with the same input" do
      let(:normalized_values) { Array.new(3) { normalizer.call("content_type") } }

      it "returns the same result each time" do
        expect(normalized_values.uniq.size).to eq 1
      end

      it "returns different string objects each time" do
        expect(normalized_values.map(&:object_id).uniq.size).to eq normalized_values.size
      end
    end

    it "limits allocation counts for first normalization of a header" do
      expected_allocations = {
        Array                  => 1,
        described_class        => 1,
        Hash                   => 1,
        described_class::Cache => 1,
        MatchData              => 1,
        String                 => 6
      }

      expect do
        normalizer.call("content_type")
      end.to limit_allocations(**expected_allocations)
    end

    it "allocates minimal memory for subsequent normalization of the same header" do
      normalizer.call("content_type")

      expect do
        normalizer.call("content_type")
      end.to limit_allocations(String => 1)
    end
  end
end
