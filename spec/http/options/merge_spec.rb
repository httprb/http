require 'spec_helper'

describe Http::Options, "merge" do

  let(:opts){ Http::Options.new }

  it 'supports a Hash' do
    old_response = opts.response
    opts.merge(:response => :body).response.should eq(:body)
    opts.response.should eq(old_response)
  end

  it 'supports another Options' do
    merged = opts.merge(Http::Options.new(:response => :body))
    merged.response.should eq(:body)
  end

  it 'merges as excepted in complex cases' do
    foo = Http::Options.new(
      :response  => :body,
      :form      => {:foo => 'foo'},
      :headers   => {:accept  => "json",  :foo => 'foo'},
      :callbacks => {:request => ["common"], :response => ["foo"]})
    bar = Http::Options.new(
      :response  => :parsed_body,
      :form      => {:bar => 'bar'},
      :headers   => {:accept  => "xml", :bar => 'bar'},
      :callbacks => {:request => ["common"], :response => ["bar"]})
    foo.merge(bar).to_hash.should eq(
      :response  => :parsed_body,
      :form      => {:bar => 'bar'},
      :headers   => {:accept  => "xml", :foo => "foo", :bar => 'bar'},
      :callbacks => {:request => ["common"], :response => ["foo", "bar"]}
    )
  end

end
