require 'spec_helper'

describe HTTP::Options, 'new' do
  let(:user_agent) { "RubyHTTPGem/#{HTTP::VERSION}" }

  it 'supports a Options instance' do
    opts = HTTP::Options.new
    expect(HTTP::Options.new(opts)).to eq(opts)
  end

  context 'with a Hash' do
    it 'coerces :response correctly' do
      opts = HTTP::Options.new(:response => :object)
      expect(opts.response).to eq(:object)
    end

    it 'coerces :headers correctly' do
      opts = HTTP::Options.new(:headers => {:accept => 'json'})
      expect(opts.headers).to eq(:accept => 'json', 'User-Agent' => user_agent)
    end

    it 'coerces :form correctly' do
      opts = HTTP::Options.new(:form => {:foo => 42})
      expect(opts.form).to eq(:foo => 42)
    end
  end
end
