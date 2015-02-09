RSpec.describe HTTP::Cache::RackCacheStoresAdapter do
  describe ".new" do
    it "accepts opts :metastore and :entitystore" do
      expect(described_class.new(:metastore => "heap:/", :entitystore => "heap:/"))
        .to be_kind_of described_class
    end
  end

  subject { described_class.new(:metastore => "heap:/", :entitystore => "heap:/") }

  describe "store and retrieve" do
    it "returns the correct response" do
      subject.store(request, response)
      expect(subject.lookup(request)).to be_equivalent_to response
    end

    it "original response is still usable after being stored" do
      subject.store(request, response)
      expect(response.body.to_s).to eq body_content
    end
  end

  describe "store, invalidate and retrieve" do
    it "returns the correct response" do
      subject.store(request, response)
      subject.invalidate(request)

      expect(subject.lookup(request)).to be_stale
    end
  end

  context "file storage" do
    subject do
      described_class.new(
        :metastore => "file:tmp/cache/meta", :entitystore => "file:tmp/cache/entity"
      )
    end

    describe "store and retrieve" do
      it "returns the correct response" do
        subject.store(request, response)

        expect(subject.lookup(request)).to be_equivalent_to response
      end
    end

    it "original response is still usable after being stored" do
      subject.store(request, response)
      expect(response.body.to_s).to eq body_content
    end
  end

  # Background
  let(:request)  { HTTP::Request.new(:get, "http://example.com").caching }
  let(:body_content) { "testing 1, 2, #{rand}" }
  let(:response) do
    HTTP::Response.new(
      200,
      "HTTP/1.1",
      {"X-test" => "#{rand}", "Date" => Time.now.httpdate, "Cache-Control" => "max-age=100"},
      HTTP::Response::Body.new(client)
    ).caching
  end
  let(:client) do
    StringIO.new(body_content).tap do |s|
      class << s
        def readpartial(*args)
          if eof?
            nil
          else
            super
          end
        end

        def to_s
          string
        end
      end
    end
  end

  matcher :be_equivalent_to do |expected|
    match do |actual|
      stringify(actual.body) == stringify(expected.body) &&
        actual.headers == expected.headers &&
        actual.status == expected.status
    end

    def stringify(body)
      body.inject("") { |a, e| a + e }
    end
  end
end
