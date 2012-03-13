require 'spec_helper'

describe Http::Options, "proxy" do

  let(:opts){ Http::Options.new }

  it 'defaults to {}' do
    opts.proxy.should eq({})
  end

  it 'may be specified with with_proxy' do
    opts2 = opts.with_proxy(:proxy_address => "127.0.0.1", :proxy_port => 8080)
    opts.proxy.should eq({})
    opts2.proxy.should eq(:proxy_address => "127.0.0.1", :proxy_port => 8080)
  end

  it 'accepts proxy address, port, username, and password' do
    opts2 = opts.with_proxy(:proxy_address => "127.0.0.1", :proxy_port => 8080, :proxy_username => "username", :proxy_password => "password")
    opts2.proxy.should eq(:proxy_address => "127.0.0.1", :proxy_port => 8080, :proxy_username => "username", :proxy_password => "password")
  end
end