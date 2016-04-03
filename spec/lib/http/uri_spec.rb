RSpec.describe HTTP::URI do
  let(:example_uri_string) { "http://example.com" }

  subject(:uri) { described_class.parse(example_uri_string) }

  it "knows URI schemes" do
    expect(uri.scheme).to eq "http"
  end
end
