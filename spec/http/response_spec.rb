require 'spec_helper'
require 'json'

describe HTTP::Response do
  describe 'headers' do
    let(:body) { double(:body) }
    subject { HTTP::Response.new(200, '1.1', {'Content-Type' => 'text/plain'}, body) }

    it 'exposes header fields for easy access' do
      expect(subject['Content-Type']).to eq('text/plain')
    end

    it 'provides a #headers accessor too' do
      expect(subject.headers).to eq('Content-Type' => 'text/plain')
    end
  end

  describe 'to_a' do
    let(:body)         { 'Hello world' }
    let(:content_type) { 'text/plain' }
    subject { HTTP::Response.new(200, '1.1', {'Content-Type' => content_type}, body) }

    it 'returns a Rack-like array' do
      expect(subject.to_a).to eq([200, {'Content-Type' => content_type}, body])
    end
  end

  describe '#parse' do
    let(:response) { HTTP::Response.new(200, '1.1', headers, body) }

    context 'with known MIME type' do
      let(:body)     { '{"hello":"world"}' }
      let(:headers)  { {'Content-Type' => 'application/json'} }

      it 'returns body parsed with proper MIME type adapter' do
        expect(response.parse).to eq 'hello' => 'world'
      end
    end

    context 'with unknown MIME type' do
      let(:body)     { '{"hello":"world"}' }
      let(:headers)  { {'Content-Type' => 'unknown/type'} }

      it 'returns stringified body as is' do
        expect(response.parse).to eq body
      end
    end
  end
end
