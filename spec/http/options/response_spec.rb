require 'spec_helper'

describe HTTP::Options, "response" do

  let(:opts){ HTTP::Options.new }

  it 'defaults to :auto' do
    expect(opts.response).to eq(:auto)
  end

  it 'may be specified with with_response' do
    opts2 = opts.with_response(:body)
    expect(opts.response).to eq(:auto)
    expect(opts2.response).to eq(:body)
  end

  it 'recognizes invalid responses' do
    expect {
      opts.with_response(:not_a_valid_response)
    }.to raise_error(ArgumentError, /not_a_valid_response/)
  end

end

