require 'spec_helper'

describe HTTP::Response::Body do
  let(:body)     { 'Hello, world!' }
  let(:response) { double(:response) }

  subject { described_class.new(response) }

  before do
    response.should_receive(:readpartial).and_return(body)
    response.should_receive(:readpartial).and_return(nil)
  end

  it 'streams bodies from responses' do
    expect(subject.to_s).to eq body
  end

  context 'when body empty' do
    let(:body) { '' }
    it 'returns responds to empty? with true' do
      expect(subject).to be_empty
    end
  end
end
