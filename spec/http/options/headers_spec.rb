require 'spec_helper'

describe HTTP::Options, 'headers' do

  let(:opts)       { HTTP::Options.new }
  let(:user_agent) { "RubyHTTPGem/#{HTTP::VERSION}" }

  it 'defaults to just the user agent' do
    expect(opts.headers).to eq('User-Agent' => user_agent)
  end

  it 'may be specified with with_headers' do
    opts2 = opts.with_headers('accept' => 'json')
    expect(opts.headers).to eq('User-Agent' => user_agent)
    expect(opts2.headers).to eq('Accept' => 'json', 'User-Agent' => user_agent)
  end

  it 'recognizes invalid headers' do
    expect { opts.with_headers(self) }.to raise_error(HTTP::Error)
  end

end
