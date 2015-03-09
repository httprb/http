RSpec.describe HTTP::Request::Caching do
  let(:request) { HTTP::Request.new(:get, "http://example.com/") }

  subject(:caching_request) { described_class.new request }

  describe "#cache_headers" do
    subject { caching_request.cache_headers }
    it { is_expected.to be_a HTTP::Cache::Headers }
  end

  context "basic GET request" do
    it "is cacheable" do
      expect(subject.cacheable?).to be_truthy
    end

    it "does not invalidate cache" do
      expect(subject.invalidates_cache?).to be_falsy
    end

    it "does not skip cache" do
      expect(subject.skips_cache?).to be_falsy
    end

    it "can construct a new conditional version of itself based on a caching response" do
      mod_date    = Time.now.httpdate
      headers     = {"Etag" => "foo", "Last-Modified" => mod_date}
      cached_resp = HTTP::Response.new(200, "http/1.1", headers, "")
      cond_req = subject.conditional_on_changes_to(cached_resp)

      expect(cond_req.headers["If-None-Match"]).to eq "foo"
      expect(cond_req.headers["If-Modified-Since"]).to eq mod_date
    end
  end

  context "GET request w/ must-revalidate" do
    let(:request) do
      headers = {"cache-control" => "must-revalidate"}
      HTTP::Request.new(:get, "http://example.com/", headers)
    end

    it "is cacheable" do
      expect(subject.cacheable?).to be_truthy
    end

    it "does not invalidate cache" do
      expect(subject.invalidates_cache?).to be_falsy
    end

    it "does not skip cache" do
      expect(subject.skips_cache?).to be_truthy
    end

    it "can construct a condition version of itself based on a caching response" do
      mod_date    = Time.now.httpdate
      headers     = {"Etag" => "foo", "Last-Modified" => mod_date}
      cached_resp = HTTP::Response.new(200, "http/1.1", headers, "")
      cond_req    = subject.conditional_on_changes_to(cached_resp)

      expect(cond_req.headers["If-None-Match"]).to eq "foo"
      expect(cond_req.headers["If-Modified-Since"]).to eq mod_date
      expect(cond_req.cache_headers.max_age).to eq 0
    end
  end

  context "basic POST request" do
    let(:request) { HTTP::Request.new(:post, "http://example.com/") }

    it "is cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "does not invalidate cache" do
      expect(subject.invalidates_cache?).to be_truthy
    end

    it "does not skip cache" do
      expect(subject.skips_cache?).to be_falsy
    end
  end

  context "basic PUT request" do
    let(:request) { HTTP::Request.new(:put, "http://example.com/") }

    it "is cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "does not invalidate cache" do
      expect(subject.invalidates_cache?).to be_truthy
    end

    it "does not skip cache" do
      expect(subject.skips_cache?).to be_falsy
    end
  end

  context "basic delete request" do
    let(:request) { HTTP::Request.new(:delete, "http://example.com/") }

    it "is cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "does not invalidate cache" do
      expect(subject.invalidates_cache?).to be_truthy
    end

    it "does not skip cache" do
      expect(subject.skips_cache?).to be_falsy
    end
  end

  context "basic patch request" do
    let(:request) { HTTP::Request.new(:patch, "http://example.com/") }

    it "is cacheable" do
      expect(subject.cacheable?).to be_falsy
    end

    it "does not invalidate cache" do
      expect(subject.invalidates_cache?).to be_truthy
    end

    it "does not skip cache" do
      expect(subject.skips_cache?).to be_falsy
    end
  end

  describe "#caching" do
    subject(:caching_request) { request.caching }
    it { is_expected.to be caching_request }
  end
end
