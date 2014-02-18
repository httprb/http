require 'spec_helper'

describe HTTP::AuthorizationHeader::BasicAuth do
  describe '.new' do
    it 'fails when options is not a Hash' do
      expect { described_class.new '[FOOBAR]' }.to raise_error
    end

    it 'fails when :pass is not given' do
      expect { described_class.new :user => '[USER]' }.to raise_error
    end

    it 'fails when :user is not given' do
      expect { described_class.new :pass => '[PASS]' }.to raise_error
    end
  end

  describe '#to_s' do
    let(:user)        { 'foo' }
    let(:pass)        { 'bar' * 100 }
    let(:user_n_pass) { user + ':' + pass }
    let(:builder)     { described_class.new :user => user, :pass => pass }

    subject { builder.to_s }

    it { should eq "Basic #{Base64.strict_encode64 user_n_pass}" }
    it { should match(/^Basic [^\s]+$/) }
  end
end
