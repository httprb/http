require 'spec_helper'

describe HTTP::Options, "callbacks" do

  let(:opts){ HTTP::Options.new }
  let(:callback){ Proc.new{|r| nil } }

  it 'recognizes invalid events' do
    expect {
      opts.with_callback(:notacallback, callback)
    }.to raise_error(ArgumentError, /notacallback/)
  end

  it 'recognizes invalid callbacks' do
    expect {
      opts.with_callback(:request, Object.new)
    }.to raise_error(ArgumentError, /invalid callback/)
    expect {
      opts.with_callback(:request, Proc.new{|a,b| nil})
    }.to raise_error(ArgumentError, /only one argument/)
  end

  describe "request" do

    it 'defaults to []' do
      expect(opts.callbacks[:request]).to eq([])
    end

    it 'may be specified with with_callback(:request, ...)' do

      opts2 = opts.with_callback(:request, callback)
      expect(opts.callbacks[:request]).to eq([])
      expect(opts2.callbacks[:request]).to eq([callback])

      opts3 = opts2.with_callback(:request, callback)
      expect(opts2.callbacks[:request]).to eq([callback])
      expect(opts3.callbacks[:request]).to eq([callback, callback])
    end

  end

  describe "response" do

    it 'defaults to []' do
      expect(opts.callbacks[:response]).to eq([])
    end

    it 'may be specified with with_callback(:response, ...)' do

      opts2 = opts.with_callback(:response, callback)
      expect(opts.callbacks[:response]).to eq([])
      expect(opts2.callbacks[:response]).to eq([callback])

      opts3 = opts2.with_callback(:response, callback)
      expect(opts2.callbacks[:response]).to eq([callback])
      expect(opts3.callbacks[:response]).to eq([callback, callback])
    end

  end

end

