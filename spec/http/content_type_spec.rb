require 'spec_helper'

describe HTTP::ContentType do
  describe '.parse' do
    context 'with text/plain' do
      subject { described_class.parse 'text/plain' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to be_nil }
      end
    end

    context 'with tEXT/plaIN' do
      subject { described_class.parse 'tEXT/plaIN' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to be_nil }
      end
    end

    context 'with text/plain; charset=utf-8' do
      subject { described_class.parse 'text/plain; charset=utf-8' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to eq 'utf-8' }
      end
    end

    context 'with text/plain; charset="utf-8"' do
      subject { described_class.parse 'text/plain; charset="utf-8"' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to eq 'utf-8' }
      end
    end

    context 'with text/plain; charSET=utf-8' do
      subject { described_class.parse 'text/plain; charSET=utf-8' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to eq 'utf-8' }
      end
    end

    context 'with text/plain; foo=bar; charset=utf-8' do
      subject { described_class.parse 'text/plain; foo=bar; charset=utf-8' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to eq 'utf-8' }
      end
    end

    context 'with text/plain;charset=utf-8;foo=bar' do
      subject { described_class.parse 'text/plain;charset=utf-8;foo=bar' }

      describe '#mime_type' do
        subject { super().mime_type }
        it { is_expected.to eq 'text/plain' }
      end

      describe '#charset' do
        subject { super().charset }
        it { is_expected.to eq 'utf-8' }
      end
    end
  end
end
