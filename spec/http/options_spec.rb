require 'spec_helper'

describe HTTP::Options do
  subject { described_class.new(:response => :body) }

  it "behaves like a Hash for reading" do
    expect(subject[:response]).to eq(:body)
    expect(subject[:nosuchone]).to be_nil
  end

  it "it's gois able to coerce to a Hash" do
    expect(subject.to_hash).to be_a(Hash)
    expect(subject.to_hash[:response]).to eq(:body)
  end

  it "raises ArgumentError with invalid options" do
    expect { subject.with_response(:notrecognized) }.to raise_exception(ArgumentError)
  end

end
