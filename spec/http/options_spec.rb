require 'spec_helper'

describe Http::Options do

  let(:options){ Http::Options.new(:response => :body) }

  it 'behaves like a Hash for reading' do
    options[:response].should eq(:body)
  end

  it 'is able to coerce to a Hash' do
    options.to_hash.should be_a(Hash)
    options.to_hash[:response].should eq(:body)
  end

end
