# frozen_string_literal: true

RSpec.describe HTTP::Options, "headers" do
  let(:opts) { HTTP::Options.new }

  it "defaults to be empty" do
    expect(opts.headers).to be_empty
  end

  it "may be specified with with_headers" do
    opts2 = opts.with_headers(:accept => "json")
    expect(opts.headers).to be_empty
    expect(opts2.headers).to eq([%w[Accept json]])
  end

  it "accepts any object that respond to :to_hash" do
    x = if RUBY_VERSION >= "3.2.0"
          Data.define(:to_hash).new(:to_hash => { "accept" => "json" })
        else
          Struct.new(:to_hash).new({ "accept" => "json" })
        end
    expect(opts.with_headers(x).headers["accept"]).to eq("json")
  end
end
