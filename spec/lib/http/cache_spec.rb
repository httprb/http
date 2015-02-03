require "support/dummy_server"

RSpec.describe HTTP::Cache do
  describe "creation" do
    subject { described_class }

    it "allows private mode" do
      expect(subject.new(cache_adapter))
        .to be_kind_of HTTP::Cache
    end

    it "allows public mode" do
      expect(subject.new(cache_adapter))
        .to be_kind_of HTTP::Cache
    end
  end

  let(:opts) { options }
  subject { described_class.new(cache_adapter) }

  describe "#perform" do
    it "calls request_performer blocck when cache miss" do
      expect { |b| subject.perform(request, opts) {|*args|
                 b.to_proc.call(*args)
                 origin_response }
      }.to yield_with_args(request, opts)
    end

    context "cache hit" do
      let(:cached_response) { HTTP::Cache::ResponseWithCacheBehavior.coerce(
        HTTP::Response.new(200, "http/1.1",
                           {"Cache-Control" => "private", "test"=> "foo"},
                           "")
      ).tap{|r| r.requested_at = r.received_at = Time.now } }

      it "does not call request_performer block" do
        expect { |b| subject.perform(request, opts, &b) }.not_to yield_control
      end
    end
  end

  context "empty cache, cacheable request, cacheable response" do
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "tries to lookup request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end

    it "stores response in cache" do
      expect(cache_adapter).to have_received(:store).with(request, origin_response)
    end
  end

  context "cache by-passing request, cacheable response" do
    let(:request) { HTTP::Request.new(:get, "http://example.com/",
                                      {"Cache-Control" => "no-cache"}) }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "doesn't lookup request" do
      expect(cache_adapter).not_to have_received(:lookup)
    end

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end

    it "stores response in cache" do
      expect(cache_adapter).to have_received(:store).with(request, origin_response)
    end
  end

  context "empty cache, cacheable request, 'nreceiver' response" do
    let(:origin_response) { HTTP::Response.new(200, "http/1.1",
                                                 {"Cache-Control" => "no-cache"},
                                                 "") }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "tries to lookup request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end

    it "doesn't store response in cache" do
      expect(cache_adapter).not_to have_received(:store)
    end

  end

  context "empty cache, cacheable request, 'no-cache' response" do
    let(:origin_response) { HTTP::Response.new(200, "http/1.1",
                                                 {"Cache-Control" => "no-store"},
                                                 "") }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "tries to lookup request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end

    it "doesn't store response in cache" do
      expect(cache_adapter).not_to have_received(:store)
    end
  end

  context "empty cache, cacheable request, 'no-store' response" do
    let(:origin_response) { HTTP::Response.new(200, "http/1.1",
                                                 {"Cache-Control" => "no-store"},
                                                 "") }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "tries to lookup request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end

    it "doesn't store response in cache" do
      expect(cache_adapter).not_to have_received(:store)
    end
  end

  context "warm cache, cacheable request, cacheable response" do
    let(:cached_response) { build_cached_response(200, "http/1.1",
                                                  {"Cache-Control" => "private"},
                                                  "") }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "lookups request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "returns cached response" do
      expect(response).to eq cached_response
    end
  end

  context "stale cache, cacheable request, cacheable response" do
    let(:cached_response) {
      build_cached_response(200, "http/1.1",
                            {"Cache-Control" => "private, max-age=1",
                             "Date" => (Time.now - 2).httpdate},
                            "") do |t|
        t.request_time = (Time.now - 2)
      end }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "lookups request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end

    it "stores fresh response in cache" do
      expect(cache_adapter).to have_received(:store).with(request, origin_response)
    end
  end

  context "stale cache, cacheable request, not modified response" do
    let(:cached_response) {
      build_cached_response(200, "http/1.1",
                            {"Cache-Control" => "private, max-age=1",
                             "Etag" => "foo",
                             "Date" => (Time.now - 2).httpdate},
                            "") do |x|
        x.request_time = (Time.now - 2)
      end }
    let(:origin_response) { HTTP::Response.new(304, "http/1.1", {}, "") }
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "lookups request" do
      expect(cache_adapter).to have_received(:lookup).with(request)
    end

    it "modifies request with conditional request headers" do
      expect(request.headers["If-None-Match"]).to eq cached_response.headers["Etag"]
      expect(request.headers["If-Modified-Since"])
        .to eq cached_response.headers["Last-Modified"]
    end

    it "returns cached servers response" do
      expect(response).to eq cached_response
    end

    it "updates the stored response in cache" do
      expect(cache_adapter).to have_received(:store).with(request, cached_response)
    end
  end


  # Background

  let(:cache_adapter) { double("cache_adapter", lookup: cached_response, store: nil) }

  let(:request) { HTTP::Request.new(:get, "http://example.com/") }

  let(:origin_response) { HTTP::Response.new(200, "http/1.1",
                                             {"Cache-Control" => "private"},
                                             "") }

  let(:cached_response) { nil } # cold cache by default

  def build_cached_response(*args)
    r = HTTP::Cache::ResponseWithCacheBehavior.coerce(HTTP::Response.new(*args))
    r.requested_at = r.received_at = Time.now

    yield r if block_given?

    r
  end

  def options()
    HTTP::Options.new()
  end
end
