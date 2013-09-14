require 'spec_helper'

describe HTTP::ResponseBody do
  let(:body)     { "Hello, world!" }
  let(:response) { double(:response) }

  subject { described_class.new(response) }
  it "streams bodies from responses" do
    response.should_receive(:readpartial).and_return(body)
    response.should_receive(:readpartial).and_return(nil)

    expect(subject.to_s).to eq body
  end
end