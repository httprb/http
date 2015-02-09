require 'fakefs/safe'

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
  end

  describe "store, invalidate and retrieve" do
    it "returns the correct response" do
      subject.store(request, response)
      subject.invalidate(request)

      expect(subject.lookup(request)).to be_stale
    end
  end

  context "file storage" do
    before do
      FakeFS.activate!
    end

    subject { described_class.new(:metastore => "file:/var/cache/http.rb-test/meta",
                                  :entitystore => "file:/var/cache/http.rb-test/entity") }

    describe "store and retrieve" do
      it "returns the correct response" do
        subject.store(request, response)

        expect(subject.lookup(request)).to be_equivalent_to response
      end
    end

    after do
      FakeFS.deactivate!
    end
  end

  # Background
  let(:request)  { HTTP::Request.new(:get, "http://example.com").caching }
  let(:response) do
    HTTP::Response.new(
      200, "HTTP/1.1",
      {"X-test" => "#{rand}", "Date" => Time.now.httpdate, "Cache-Control" => "max-age=100"},
      "testing 1, 2, #{rand}").caching
  end

  matcher :be_equivalent_to do |expected|
    match do |actual|
      stringify(actual.body) == stringify(expected.body) &&
        actual.headers == expected.headers &&
        actual.status == expected.status
    end

    def stringify(body)
      body.reduce(""){|b,part| b << part}
    end
  end
end
