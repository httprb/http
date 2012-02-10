require 'spec_helper'

describe Http::Options, "callbacks" do

  let(:opts){ Http::Options.new }
  let(:callback){ Proc.new{|r| nil } }

  it 'recognizes invalid events' do
    lambda{
      opts.with_callback(:notacallback, callback)
    }.should raise_error(ArgumentError, /notacallback/)
  end

  it 'recognizes invalid callbacks' do
    lambda{
      opts.with_callback(:request, Object.new)
    }.should raise_error(ArgumentError, /invalid callback/)
    lambda{
      opts.with_callback(:request, Proc.new{|a,b| nil})
    }.should raise_error(ArgumentError, /only one argument/)
  end

  describe "request" do

    it 'defaults to []' do
      opts.callbacks[:request].should eq([])
    end

    it 'may be specified with with_callback(:request, ...)' do

      opts2 = opts.with_callback(:request, callback)
      opts.callbacks[:request].should eq([])
      opts2.callbacks[:request].should eq([callback])

      opts3 = opts2.with_callback(:request, callback)
      opts2.callbacks[:request].should eq([callback])
      opts3.callbacks[:request].should eq([callback, callback])
    end

  end

  describe "response" do

    it 'defaults to []' do
      opts.callbacks[:response].should eq([])
    end

    it 'may be specified with with_callback(:response, ...)' do

      opts2 = opts.with_callback(:response, callback)
      opts.callbacks[:response].should eq([])
      opts2.callbacks[:response].should eq([callback])

      opts3 = opts2.with_callback(:response, callback)
      opts2.callbacks[:response].should eq([callback])
      opts3.callbacks[:response].should eq([callback, callback])
    end

  end

end

