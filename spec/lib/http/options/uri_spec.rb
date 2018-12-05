# frozen_string_literal: true

RSpec.describe HTTP::Options, "uri" do
  let(:opts) { HTTP::Options.new }

  it "defaults to nil" do
    expect(opts.uri).to be(nil)
  end

  it "may be specified with with_uri" do
    opts2 = opts.with_uri("https://example.com")
    expect(opts.uri).to be(nil)
    expect(opts2.uri).to eq(HTTP::URI.parse("https://example.com"))
  end
end
