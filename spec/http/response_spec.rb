require 'spec_helper'

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

  describe 'mime_type' do
    it 'strips out charset' do
      headers  = {'Content-Type' => 'text/html; charset=utf8'}
      response = HTTP::Response.new 200, '1.1', headers, ''
      expect(response.mime_type).to eq 'text/html'
    end
  end
end
