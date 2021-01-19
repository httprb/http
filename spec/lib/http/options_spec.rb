# frozen_string_literal: true

RSpec.describe HTTP::Options do
  subject { described_class.new(:response => :body) }

  it "has reader methods for attributes" do
    expect(subject.response).to eq(:body)
  end

  it "coerces to a Hash" do
    expect(subject.to_hash).to be_a(Hash)
  end

  # Pattern Matching only exists in Ruby 2.7+, guard against execution of
  # tests otherwise
  if RUBY_VERSION >= '2.7'
    describe '#to_hash' do
      it 'returns a Hash representation of Options' do
        expect(subject.to_hash).to include({
          body: nil,
          cookies: {},
          encoding: nil,
          features: {},
          follow: nil,
          form: nil,
          headers: an_instance_of(HTTP::Headers),
          json: nil,
          keep_alive_timeout: 5,
          nodelay: false,
          params: nil,
          persistent: nil,
          proxy: {},
          response: :body,
          socket_class: TCPSocket,
          ssl: {},
          ssl_context: nil,
          ssl_socket_class: OpenSSL::SSL::SSLSocket,
          timeout_class: HTTP::Timeout::Null,
          timeout_options: {},
        })
      end
    end

    describe 'Pattern Matching' do
      it 'can perform a pattern match' do
        value =
          case subject
          in keep_alive_timeout: 5..10
            true
          else
            false
          end

        expect(value).to eq(true)
      end
    end
  end
end
