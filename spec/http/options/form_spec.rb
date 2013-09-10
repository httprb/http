require 'spec_helper'

describe HTTP::Options, "form" do

  let(:opts){ HTTP::Options.new }

  it 'defaults to nil' do
    opts.form.should be_nil
  end

  it 'may be specified with with_form_data' do
    opts2 = opts.with_form(:foo => 42)
    opts.form.should be_nil
    opts2.form.should eq(:foo => 42)
  end

end

