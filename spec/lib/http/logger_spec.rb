RSpec.describe HTTP::Logger do
  describe ".new" do
    let(:logger) { double("logger") }

    context "logger" do
      subject do
        described_class.new(logger).logger
      end

      it { is_expected.to eql logger }
    end

    context "print options" do
      context "with default options" do
        subject do
          described_class.new(logger).print_options
        end

        let(:expected_print_options) do
          {
            :skip_headers => true,
            :skip_body    => true,
            :separator    => "\n"
          }
        end

        it { is_expected.to eq expected_print_options }
      end

      context "with headers" do
        subject do
          described_class.new(logger, :with => [:headers]).print_options
        end

        let(:expected_print_options) do
          {
            :skip_headers => false,
            :skip_body    => true,
            :separator    => "\n"
          }
        end

        it { is_expected.to eq expected_print_options }
      end

      context "with body" do
        subject do
          described_class.new(logger, :with => [:body]).print_options
        end

        let(:expected_print_options) do
          {
            :skip_headers => true,
            :skip_body    => false,
            :separator    => "\n"
          }
        end

        it { is_expected.to eq expected_print_options }
      end

      context "with headers and body" do
        subject do
          described_class.new(logger, :with => [:headers, :body]).print_options
        end

        let(:expected_print_options) do
          {
            :skip_headers => false,
            :skip_body    => false,
            :separator    => "\n"
          }
        end

        it { is_expected.to eq expected_print_options }
      end
    end
  end

  describe "#log" do
    let(:request)  { double("request") }
    let(:response) { double("response") }
    let(:logger) { double("logger") }
    subject { described_class.new(logger) }

    before do
      allow(logger).to receive(:info)
      allow(request).to receive(:pretty_print).with(subject.print_options).and_return("request print")
      allow(response).to receive(:pretty_print).with(subject.print_options).and_return("response print")
    end

    it "logs request" do
      expect(logger).to receive(:info).with("request print")

      subject.log(request, response)
    end

    it "logs response" do
      expect(logger).to receive(:info).with("response print")

      subject.log(request, response)
    end
  end
end
