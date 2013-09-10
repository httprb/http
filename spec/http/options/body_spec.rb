require 'spec_helper'

describe HTTP::Options, "body" do

  let(:opts){ HTTP::Options.new }

  it 'defaults to nil' do
    opts.body.should be_nil
  end

  it 'may be specified with with_body' do
    opts2 = opts.with_body("foo")
    opts.body.should be_nil
    opts2.body.should eq("foo")
  end

end

