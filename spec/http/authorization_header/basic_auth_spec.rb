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
    let(:user)        { 'foobar' }
    let(:pass)        { 'foobar' }
    let(:credentials) { "#{user}:#{pass}" }
    let(:builder)     { described_class.new :user => user, :pass => pass }

    subject { builder.to_s }

    it { should eq "Basic #{Base64.encode64 credentials}" }
  end
end
