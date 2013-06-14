require 'spec_helper'

describe Http::Options do
  subject { described_class.new(:response => :body) }

  it "behaves like a Hash for reading" do
    subject[:response].should eq(:body)
    subject[:nosuchone].should be_nil
  end

  it "it's gois able to coerce to a Hash" do
    subject.to_hash.should be_a(Hash)
    subject.to_hash[:response].should eq(:body)
  end

  it "raises ArgumentError with invalid options" do
    expect { subject.with_response(:notrecognized) }.to raise_exception(ArgumentError)
  end

end
