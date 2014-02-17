require 'spec_helper'

describe HTTP::AuthorizationHeader do
  describe '.build' do
    context 'with unkown type' do
      let(:type) { :foobar }
      let(:opts) { {:foo => :bar} }

      it 'fails' do
        expect { described_class.build type, opts }.to raise_error
      end
    end

    context 'with :basic type' do
      let(:type) { :basic }
      let(:opts) { {:user => 'user', :pass => 'pass'} }

      it 'passes options to BasicAuth' do
        expect(described_class::BasicAuth).to receive(:new).with(opts)
        described_class.build type, opts
      end
    end

    context 'with :bearer type' do
      let(:type) { :bearer }
      let(:opts) { {:token => 'token', :encode => true} }

      it 'passes options to BearerToken' do
        expect(described_class::BearerToken).to receive(:new).with(opts)
        described_class.build type, opts
      end
    end
  end

  describe '.register' do
    it 'registers given klass in builders registry' do
      described_class.register :dummy, Class.new { def initialize(*); end }
      expect { described_class.build(:dummy, 'foobar') }.to_not raise_error
    end
  end
end
