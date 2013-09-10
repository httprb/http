require 'spec_helper'

describe HTTP::Options, "merge" do

  let(:opts)       { HTTP::Options.new }
  let(:user_agent) { "RubyHTTPGem/#{HTTP::VERSION}" }

  it 'supports a Hash' do
    old_response = opts.response
    expect(opts.merge(:response => :body).response).to eq(:body)
    expect(opts.response).to eq(old_response)
  end

  it 'supports another Options' do
    merged = opts.merge(HTTP::Options.new(:response => :body))
    expect(merged.response).to eq(:body)
  end

  it 'merges as excepted in complex cases' do
    # FIXME: yuck :(

    foo = HTTP::Options.new(
      :response  => :body,
      :params      => {:baz => 'bar'},
      :form      => {:foo => 'foo'},
      :body      => "body-foo",
      :headers   => {:accept  => "json",  :foo => 'foo'},
      :proxy     => {},
      :callbacks => {:request => ["common"], :response => ["foo"]})
    bar = HTTP::Options.new(
      :response  => :parsed_body,
      :params      => {:plop => 'plip'},
      :form      => {:bar => 'bar'},
      :body      => "body-bar",
      :headers   => {:accept  => "xml", :bar => 'bar'},
      :proxy     => {:proxy_address => "127.0.0.1", :proxy_port => 8080},
      :callbacks => {:request => ["common"], :response => ["bar"]})
    expect(foo.merge(bar).to_hash).to eq(
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
