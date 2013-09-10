require 'spec_helper'

describe HTTP::Options, "new" do
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
      opts = HTTP::Options.new(:headers => {:accept => "json"})
      expect(opts.headers).to eq(:accept => "json", "User-Agent" => user_agent)
    end

    it 'coerces :proxy correctly' do
      opts = HTTP::Options.new(:proxy => {:proxy_address => "127.0.0.1", :proxy_port => 8080})
      expect(opts.proxy).to eq(:proxy_address => "127.0.0.1", :proxy_port => 8080)
    end

    it 'coerces :form correctly' do
      opts = HTTP::Options.new(:form => {:foo => 42})
      expect(opts.form).to eq(:foo => 42)
    end

    it 'coerces :callbacks correctly' do
      before, after = Proc.new{|r| :before}, Proc.new{|r| :after}
      callbacks = {:request => [before], :response => [after]}
      opts = HTTP::Options.new(:callbacks => callbacks)
      expect(opts.callbacks).to eq({
        :request  => [before],
        :response => [after]
      })
    end

  end

end
