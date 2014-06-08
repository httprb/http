require 'spec_helper'

describe HTTP::Response::Status do
  describe '.new' do
    it 'fails if given value does not respond to #to_i' do
      expect { described_class.new double }.to raise_error
    end

    it 'accepts any object that responds to #to_i' do
      expect { described_class.new double :to_i => 200 }.to_not raise_error
    end
  end

  describe '#code' do
    subject { described_class.new('200.0').code }
    it { should eq 200 }
    it { should be_a Fixnum }
  end

  describe '#reason' do
    context 'with unknown code' do
      it 'returns nil' do
        status = described_class.new 0
        expect(status.reason).to be_nil
      end
    end

    context 'with well-known code' do
      it 'returns reason message' do
        HTTP::Response::Status::REASONS.each do |code, reason|
          status = described_class.new code
          expect(status.reason).to eq reason
        end
      end
    end
  end

  describe '#inspect' do
    it 'returns quoted code and reason phrase' do
      status = described_class.new 200
      expect(status.inspect).to eq '"200 OK"'
    end
  end

  HTTP::Response::Status::REASONS.each do |code, reason|
    method = reason.downcase.gsub(/[^a-z ]+/, ' ').gsub(/ +/, '_') << '?'

    class_eval <<-RUBY
      describe '##{method}' do
        subject { status.#{method} }

        context 'when code is #{code}' do
          let(:status) { described_class.new #{code} }
          it { should be true }
        end

        context 'when code is higher than #{code}' do
          let(:status) { described_class.new #{code + 1} }
          it { should be false }
        end

        context 'when code is lower than #{code}' do
          let(:status) { described_class.new #{code - 1} }
          it { should be false }
        end
      end
    RUBY
  end
end
