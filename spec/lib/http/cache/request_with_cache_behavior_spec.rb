RSpec.describe HTTP::Cache::RequestWithCacheBehavior do
  describe ".coerce" do
    it "should accept a base request" do
      expect(described_class.coerce(request)).to be_kind_of described_class
    end

    it "should accept an already decorated request" do
      decorated_req = described_class.coerce(request)
      expect(decorated_req).to be_kind_of described_class
    end
  end

  subject { described_class.coerce(request) }

  it "provides access to it's cache control object" do
    expect(subject.cache_control).to be_kind_of HTTP::Cache::CacheControl
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

    it "can turn itself into a condition request based on a cached response" do
      mod_date = Time.now.httpdate
      cached_resp = HTTP::Response.new(200, "http/1.1",
                                       {"Etag" => "foo",
                                        "Last-Modified" => mod_date},
                                       "")
      subject.set_validation_headers!(cached_resp)
      expect(subject.headers["If-None-Match"]).to eq "foo"
      expect(subject.headers["If-Modified-Since"]).to eq mod_date
    end
  end

  context "GET request w/ must-revalidate" do
    let(:request) do
      HTTP::Request.new(:get,
                        "http://example.com/",
                        "cache-control" => "must-revalidate")
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

    it "can turn itself into a condition request based on a cached response" do
      mod_date = Time.now.httpdate
      cached_resp = HTTP::Response.new(200, "http/1.1",
                                       {"Etag" => "foo",
                                        "Last-Modified" => mod_date},
                                       "")
      subject.set_validation_headers!(cached_resp)
      expect(subject.headers["If-None-Match"]).to eq "foo"
      expect(subject.headers["If-Modified-Since"]).to eq mod_date
      expect(subject.cache_control.max_age).to eq 0
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

  # Background
  let(:request) { HTTP::Request.new(:get, "http://example.com/") }
end
