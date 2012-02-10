require 'spec_helper'

describe Http::Options do

  let(:options){ Http::Options.new(:response => :body) }

  it 'behaves like a Hash for reading' do
    options[:response].should eq(:body)
    options[:nosuchone].should be_nil
  end

  it 'is able to coerce to a Hash' do
    options.to_hash.should be_a(Hash)
    options.to_hash[:response].should eq(:body)
  end

  it 'is stacktrace friendly' do
    begin
      options.with_response(:notrecognized)
      true.should be_false
    rescue ArgumentError => ex
      puts ex.backtrace.first.should match(/options_spec/)
    end
  end

end
