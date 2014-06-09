require 'spec_helper'

RSpec.describe HTTP::AuthorizationHeader::BearerToken do
  describe '.new' do
    it 'fails when options is not a Hash' do
      expect { described_class.new '[TOKEN]' }.to raise_error
    end

    it 'fails when :token is not given' do
      expect { described_class.new :encode => true }.to raise_error
    end
  end

  describe '#to_s' do
    let(:token)   { 'foobar' * 100 }
    let(:builder) { described_class.new options.merge :token => token }

    subject { builder.to_s }

    context 'when :encode => true' do
      let(:options) { {:encode => true} }
      it { is_expected.to eq "Bearer #{Base64.strict_encode64 token}" }
      it { is_expected.to match(/^Bearer [^\s]+$/) }
    end

    context 'when :encode => false' do
      let(:options) { {:encode => false} }
      it { is_expected.to eq "Bearer #{token}" }
    end

    context 'when :encode not specified' do
      let(:options) { {} }
      it { is_expected.to eq "Bearer #{token}" }
    end
  end
end
