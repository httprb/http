require 'spec_helper'

describe Http::Options, "merge" do

  let(:opts)       { Http::Options.new }
  let(:user_agent) { "RubyHttpGem/#{Http::VERSION}" }

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
    # FIXME: yuck :(

    foo = Http::Options.new(
      :response  => :body,
      :params      => {:baz => 'bar'},
      :form      => {:foo => 'foo'},
      :body      => "body-foo",
      :headers   => {:accept  => "json",  :foo => 'foo'},
      :proxy     => {},
      :callbacks => {:request => ["common"], :response => ["foo"]})
    bar = Http::Options.new(
      :response  => :parsed_body,
      :params      => {:plop => 'plip'},
      :form      => {:bar => 'bar'},
      :body      => "body-bar",
      :headers   => {:accept  => "xml", :bar => 'bar'},
      :proxy     => {:proxy_address => "127.0.0.1", :proxy_port => 8080},
      :callbacks => {:request => ["common"], :response => ["bar"]})
    foo.merge(bar).to_hash.should eq(
      :response  => :parsed_body,
      :params=>{:plop=>"plip"}, 
      :form      => {:bar => 'bar'},
      :body      => "body-bar",
      :headers   => {:accept  => "xml", :foo => "foo", :bar => 'bar', "User-Agent" => user_agent},
      :proxy     => {:proxy_address => "127.0.0.1", :proxy_port => 8080},
      :callbacks => {:request => ["common"], :response => ["foo", "bar"]},
      :follow => nil,
      :socket_class     => described_class.default_socket_class,
      :ssl_socket_class => described_class.default_ssl_socket_class,
      :ssl_context      => nil
    )
  end
end
