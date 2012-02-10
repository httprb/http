require 'spec_helper'

describe Http::Options, "headers" do

  let(:opts){ Http::Options.new }

  it 'defaults to {}' do
    opts.headers.should eq({})
  end

  it 'may be specified with with_headers' do
    opts2 = opts.with_headers("accept" => "json")
    opts.headers.should eq({})
    opts2.headers.should eq("accept" => "json")
  end

  it 'accepts any object that respond to :to_hash' do
    x = Struct.new(:to_hash).new("accept" => "json")
    opts.with_headers(x).headers["accept"].should eq("json")
  end

  it 'recognizes invalid headers' do
    lambda{
      opts.with_headers(self)
    }.should raise_error(ArgumentError)
  end

end

