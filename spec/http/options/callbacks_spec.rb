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
      opts.with_callback(:before, Object.new)
    }.should raise_error(ArgumentError, /invalid callback/)
  end

  describe "before/request" do

    it 'defaults to []' do
      opts.before.should eq([])
    end

    it 'may be specified with with_callback(:before)' do
      opts2 = opts.with_callback(:before, callback)
      opts.before.should eq([])
      opts2.before.last.should eq(callback)
    end

    it 'may be specified with with_callback(:request)' do
      opts2 = opts.with_callback(:request, callback)
      opts.before.should eq([])
      opts2.before.last.should eq(callback)
    end

  end

  describe "after/response" do

    it 'defaults to []' do
      opts.after.should eq([])
    end

    it 'may be specified with with_callback(:after)' do
      opts2 = opts.with_callback(:after, callback)
      opts.after.should eq([])
      opts2.after.last.should eq(callback)
    end

    it 'may be specified with with_callback(:response)' do
      opts2 = opts.with_callback(:response, callback)
      opts.after.should eq([])
      opts2.after.last.should eq(callback)
    end

  end

end

