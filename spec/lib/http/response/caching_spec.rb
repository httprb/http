RSpec.describe HTTP::Response::Caching do
  let(:cache_control) { "" }
  let(:headers) { {"cache-control" => cache_control} }
  let(:response) { HTTP::Response.new(200, "http/1.1", headers, "") }

  subject(:caching_response) { described_class.new response }

  describe "#cache_headers" do
    subject { caching_response.cache_headers }
    it { is_expected.to be_a HTTP::Cache::Headers }
  end

  it "allows requested_at to be set" do
    subject.requested_at = Time.now
    expect(subject.requested_at).to be_within(1).of(Time.now)
  end

  it "allows received_at to be set" do
    subject.received_at = Time.now
    expect(subject.received_at).to be_within(1).of(Time.now)
  end

  describe "basic 200 response w/ private cache control" do
    let(:cache_control) { "private" }

    it "is cacheable" do
      expect(subject.cacheable?).to be_truthy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end
  end

  describe "basic 200 response w/ public cache control" do
    let(:cache_control) { "public" }

    it "is cacheable" do
      expect(subject.cacheable?).to be_truthy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end
  end

  describe "basic 200 response w/ no-cache" do
    let(:cache_control) { "no-cache" }

    it "is not cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end
  end

  describe "basic 200 response w/ no-store" do
    let(:cache_control) { "no-store" }

    it "is not cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end
  end

  describe "basic 200 response w/ max age" do
    let(:cache_control) { "max-age=100" }

    it "is not cacheable" do
      expect(subject.cacheable?).to be_truthy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end
  end

  describe "basic 200 response w/ public & max age" do
    let(:cache_control) { "public, max-age=100" }

    it "is not cacheable" do
      expect(subject.cacheable?).to be_truthy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end

    context "with age of max-age + 1 seconds" do
      let(:headers) { {"cache-control" => cache_control, "age" => "101"} }

      it "is stale" do
        expect(subject.stale?).to be_truthy
      end

      it "is expired" do
        expect(subject.expired?).to be_truthy
      end

      it "is expected to be max-age + 1 seconds old" do
        expect(subject.current_age).to be_within(1).of(101)
      end
    end

    context "after max-age + 1 seconds" do
      before do
        subject.received_at = subject.requested_at = (Time.now - 101)
      end

      it "is stale" do
        expect(subject.stale?).to be_truthy
      end

      it "is expired" do
        expect(subject.expired?).to be_truthy
      end

      it "is expected to be max-age + 1 seconds old" do
        expect(subject.current_age).to be_within(1).of(101)
      end
    end
  end

  describe "basic 400 response " do
    let(:response) { HTTP::Response.new(400, "http/1.1", {}, "") }

    it "is not cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "is not stale" do
      expect(subject.stale?).to be_falsy
    end

    it "is not expired" do
      expect(subject.expired?).to be_falsy
    end

    it "is expected to be 0 seconds old" do
      expect(subject.current_age).to be_within(1).of(0)
    end
  end

  describe "#caching" do
    subject(:caching_response) { response.caching }
    it { is_expected.to be_kind_of described_class }
  end
end
