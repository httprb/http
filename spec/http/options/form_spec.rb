require 'spec_helper'

describe HTTP::Options, "form" do

  let(:opts){ HTTP::Options.new }

  it 'defaults to nil' do
    expect(opts.form).to be_nil
  end

  it 'may be specified with with_form_data' do
    opts2 = opts.with_form(:foo => 42)
    expect(opts.form).to be_nil
    expect(opts2.form).to eq(:foo => 42)
  end

end

