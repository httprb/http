require 'spec_helper'

describe Http::Options, "new" do

  it 'supports a Options instance' do
    opts = Http::Options.new
    Http::Options.new(opts).should eq(opts)
  end

  context 'with a Hash' do

    it 'coerces :response correctly' do
      opts = Http::Options.new(:response => :object)
      opts.response.should eq(:object)
    end

    it 'coerces :headers correctly' do
      opts = Http::Options.new(:headers => {:accept => "json"})
      opts.headers.should eq(:accept => "json", "User-Agent"=>"HTTP Gem")
    end

    it 'coerces :proxy correctly' do
      opts = Http::Options.new(:proxy => {:proxy_address => "127.0.0.1", :proxy_port => 8080})
      opts.proxy.should eq(:proxy_address => "127.0.0.1", :proxy_port => 8080)
    end

    it 'coerces :form correctly' do
      opts = Http::Options.new(:form => {:foo => 42})
      opts.form.should eq(:foo => 42)
    end

    it 'coerces :callbacks correctly' do
      before, after = Proc.new{|r| :before}, Proc.new{|r| :after}
      callbacks = {:request => [before], :response => [after]}
      opts = Http::Options.new(:callbacks => callbacks)
      opts.callbacks.should eq({
        :request  => [before],
        :response => [after]
      })
    end

  end

end
