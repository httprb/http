# frozen_string_literal: true

RSpec.describe HTTP::URI do
  let(:example_http_uri_string)  { "http://example.com" }
  let(:example_https_uri_string) { "https://example.com" }

  subject(:http_uri)  { described_class.parse(example_http_uri_string) }
  subject(:https_uri) { described_class.parse(example_https_uri_string) }

  it "knows URI schemes" do
    expect(http_uri.scheme).to eq "http"
    expect(https_uri.scheme).to eq "https"
  end

  it "sets default ports for HTTP URIs" do
    expect(http_uri.port).to eq 80
  end

  it "sets default ports for HTTPS URIs" do
    expect(https_uri.port).to eq 443
  end

  describe "#dup" do
    it "doesn't share internal value between duplicates" do
      duplicated_uri = http_uri.dup
      duplicated_uri.host = "example.org"

      expect(duplicated_uri.to_s).to eq("http://example.org")
      expect(http_uri.to_s).to eq("http://example.com")
    end
  end

  # Pattern Matching only exists in Ruby 2.7+, guard against execution of
  # tests otherwise
  if RUBY_VERSION >= '2.7'
    describe '#to_h' do
      it 'returns a Hash representation of a URI' do
        expect(http_uri.to_h).to include({
          fragment: nil,
          host: "example.com",
          password: nil,
          path: "",
          port: 80,
          query: nil,
          scheme: "http",
          user: nil
        })
      end
    end

    describe 'Pattern Matching' do
      it 'can perform a pattern match' do
        value =
          case http_uri
          in host: /example/, port: 50..100, scheme: 'http'
            true
          else
            false
          end

        expect(value).to eq(true)
      end
    end
  end
end
