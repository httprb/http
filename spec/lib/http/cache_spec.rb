require "support/dummy_server"
require "http/cache"

RSpec.describe HTTP::Cache do
  describe "creation" do
    subject { described_class }

    it "allows metastore and entitystore" do
      expect(subject.new(:metastore => "heap:/", :entitystore => "heap:/")).
        to be_kind_of HTTP::Cache
    end
  end

  let(:opts) { options }
  let(:sn) { SecureRandom.urlsafe_base64(3) }
  let(:request) { HTTP::Request.new(:get, "http://example.com/#{sn}") }

  let(:origin_response) do
    HTTP::Response.new(
      :status => 200,
      :version => "http/1.1",
      :headers => {"Cache-Control" => "private"},
      :body => "origin")
  end

  subject { described_class.new(:metastore => "heap:/", :entitystore => "heap:/") }

  describe "#perform" do
    it "calls request_performer blocck when cache miss" do
      expect do |b|
        subject.perform(request, opts) do |*args|
          b.to_proc.call(*args)
          origin_response
        end
      end.to yield_with_args(request, opts)
    end

    context "cache hit" do
      it "does not call request_performer block" do
        subject.perform(request, opts) do |*_t|
          origin_response
        end

        expect { |b| subject.perform(request, opts, &b) }.not_to yield_control
      end
    end
  end

  context "empty cache, cacheable request, cacheable response" do
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end
  end

  context "cache by-passing request, cacheable response" do
    let(:request) do
      headers = {"Cache-Control" => "no-cache"}
      HTTP::Request.new(:get, "http://example.com/", headers)
    end
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end
  end

  context "empty cache, cacheable request, 'no-cache' response" do
    let(:origin_response) do
      HTTP::Response.new(
        :status => 200,
        :version => "http/1.1",
        :headers => {"Cache-Control" => "no-store"},
        :body => "")
    end
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end
  end

  context "empty cache, cacheable request, 'no-store' response" do
    let(:origin_response) do
      HTTP::Response.new(
        :status => 200,
        :version => "http/1.1",
        :headers => {"Cache-Control" => "no-store"},
        :body => "")
    end
    let!(:response) { subject.perform(request, opts) { origin_response } }

    it "returns origin servers response" do
      expect(response).to eq origin_response
    end
  end

  context "warm cache, cacheable request, cacheable response" do
    let(:cached_response) do
      build_cached_response(
        :status => 200,
        :version => "1.1",
        :headers => {"Cache-Control" => "max-age=100"},
        :body => "cached")
    end
    before do
      subject.perform(request, opts) { cached_response }
    end

    let(:response) { subject.perform(request, opts) { origin_response } }

    it "returns cached response" do
      expect(response.body.to_s).to eq cached_response.body.to_s
    end
  end

  context "stale cache, cacheable request, cacheable response" do
    let(:cached_response) do
      build_cached_response(
        :status => 200,
        :version => "1.1",
        :headers => {"Cache-Control" => "private, max-age=1",
                     "Date" => (Time.now - 2).httpdate},
        :body => "cached"
      ) do |t|
        t.requested_at = (Time.now - 2)
      end
    end
    before do
      subject.perform(request, opts) { cached_response }
    end
    let(:response) { subject.perform(request, opts) { origin_response } }

    it "returns origin servers response" do
      expect(response.body.to_s).to eq origin_response.body.to_s
    end
  end

  context "stale cache, cacheable request, not modified response" do
    let(:cached_response) do
      build_cached_response(
        :status => 200,
        :version => "http/1.1",
        :headers => {"Cache-Control" => "private, max-age=1",
                     "Etag" => "foo",
                     "Date" => (Time.now - 2).httpdate},
        :body => ""
      ) do |x|
        x.requested_at = (Time.now - 2)
      end
    end
    before do
      subject.perform(request, opts) { cached_response }
    end

    let(:origin_response) do
      HTTP::Response.new(
        :status => 304,
        :version => "http/1.1",
        :body => ""
      )
    end
    let(:response) { subject.perform(request, opts) { origin_response } }

    it "makes request with conditional request headers" do
      subject.perform(request, opts) do |actual_request, _|
        expect(actual_request.headers["If-None-Match"]).
          to eq cached_response.headers["Etag"]
        expect(actual_request.headers["If-Modified-Since"]).
          to eq cached_response.headers["Last-Modified"]

        origin_response
      end
    end

    it "returns cached servers response" do
      expect(response.body.to_s).to eq cached_response.body.to_s
    end
  end

  let(:cached_response) { nil } # cold cache by default

  def build_cached_response(opts)
    r = HTTP::Response.new(opts).caching
    r.requested_at = r.received_at = Time.now

    yield r if block_given?

    r
  end

  def options
    HTTP::Options.new
  end
end
