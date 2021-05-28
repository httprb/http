# frozen_string_literal: true

RSpec.describe HTTP::ContentType do
  describe ".parse" do
    context "with text/plain" do
      subject { described_class.parse "text/plain" }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to be_nil }
    end

    context "with tEXT/plaIN" do
      subject { described_class.parse "tEXT/plaIN" }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to be_nil }
    end

    context "with text/plain; charset=utf-8" do
      subject { described_class.parse "text/plain; charset=utf-8" }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to eq "utf-8" }
    end

    context 'with text/plain; charset="utf-8"' do
      subject { described_class.parse 'text/plain; charset="utf-8"' }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to eq "utf-8" }
    end

    context "with text/plain; charSET=utf-8" do
      subject { described_class.parse "text/plain; charSET=utf-8" }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to eq "utf-8" }
    end

    context "with text/plain; foo=bar; charset=utf-8" do
      subject { described_class.parse "text/plain; foo=bar; charset=utf-8" }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to eq "utf-8" }
    end

    context "with text/plain;charset=utf-8;foo=bar" do
      subject { described_class.parse "text/plain;charset=utf-8;foo=bar" }
      its(:mime_type) { is_expected.to eq "text/plain" }
      its(:charset)   { is_expected.to eq "utf-8" }
    end
  end

  # Pattern Matching only exists in Ruby 2.7+, guard against execution of
  # tests otherwise
  if RUBY_VERSION >= "2.7"
    describe "#to_h" do
      it "returns a Hash representation of a Content Type" do
        expect(described_class.new("text/plain", "utf-8").to_h).to include(
          :charset   => "utf-8",
          :mime_type => "text/plain"
        )
      end
    end

    describe "Pattern Matching" do
      it "can perform a pattern match" do
        # Cursed hack to ignore syntax errors to test Pattern Matching.
        value = instance_eval <<-RUBY, __FILE__, __LINE__ + 1
          case described_class.new('text/plain', 'utf-8')
          in mime_type: /text/
            true
          else
            false
          end
        RUBY

        expect(value).to eq(true)
      end
    end
  end
end
