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

    it "retuns mutable strings" do
      normalized_headers = Array.new(3) { normalizer.call("content_type") }

      expect(normalized_headers)
        .to satisfy { |arr| arr.uniq.size == 1 }
        .and(satisfy { |arr| arr.map(&:object_id).uniq.size == normalized_headers.size })
        .and(satisfy { |arr| arr.none?(&:frozen?) })
    end

    it "allocates minimal memory for normalization of the same header" do
      normalizer.call("accept") # XXX: Ensure normalizer is pre-allocated

      # On first call it is expected to allocate during normalization
      expect { normalizer.call("content_type") }.to limit_allocations(
        Array     => 1,
        MatchData => 1,
        String    => 6
      )

      # On subsequent call it is expected to only allocate copy of a cached string
      expect { normalizer.call("content_type") }.to limit_allocations(
        Array     => 0,
        MatchData => 0,
        String    => 1
      )
    end
  end
end
