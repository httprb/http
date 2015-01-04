RSpec.describe HTTP::Options do
  subject { described_class.new(:response => :body) }

  it "behaves like a Hash for reading" do
    expect(subject[:response]).to eq(:body)
    expect(subject[:nosuchone]).to be nil
  end

  it "coerces to a Hash" do
    expect(subject.to_hash).to be_a(Hash)
  end
end
