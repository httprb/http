require 'spec_helper'

describe HTTP::Response do
  describe '#headers' do
    let(:body)      { double(:body) }
    let(:headers)   { {'Content-Type' => 'text/plain'} }

    subject(:response) { HTTP::Response.new(200, '1.1', headers, body) }

    it 'is an instance of Headers' do
      expect(response.headers).to be_a HTTP::Headers
    end

    context 'with duplicate header keys (mixed case)' do
      let(:headers) { {'Set-Cookie' => 'a=1;', 'set-cookie' => 'b=2;'} }

      it 'groups values into Array' do
        expect(response['Set-Cookie']).to match_array ['a=1;', 'b=2;']
      end
    end
  end

  describe '#[]' do
    let(:body) { double(:body) }
    let(:response) { HTTP::Response.new(200, '1.1', {}, body) }

    it 'is proxied to #headers' do
      expect(response.headers).to receive(:[]).with(:cookie)
      response[:cookie]
    end
  end

  describe '#[]=' do
    let(:body) { double(:body) }
    let(:response) { HTTP::Response.new(200, '1.1', {}, body) }

    it 'is proxied to #headers' do
      expect(response.headers).to receive(:[]=).with(:cookie, 'foo=bar;')
      response[:cookie] = 'foo=bar;'
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
    subject { HTTP::Response.new(200, '1.1', headers, '').mime_type }

    context 'without Content-Type header' do
      let(:headers) { {} }
      it { should be_nil }
    end

    context 'with Content-Type: text/html' do
      let(:headers) { {'Content-Type' => 'text/html'} }
      it { should eq 'text/html' }
    end

    context 'with Content-Type: text/html; charset=utf-8' do
      let(:headers) { {'Content-Type' => 'text/html; charset=utf-8'} }
      it { should eq 'text/html' }
    end
  end

  describe 'charset' do
    subject { HTTP::Response.new(200, '1.1', headers, '').charset }

    context 'without Content-Type header' do
      let(:headers) { {} }
      it { should be_nil }
    end

    context 'with Content-Type: text/html' do
      let(:headers) { {'Content-Type' => 'text/html'} }
      it { should be_nil }
    end

    context 'with Content-Type: text/html; charset=utf-8' do
      let(:headers) { {'Content-Type' => 'text/html; charset=utf-8'} }
      it { should eq 'utf-8' }
    end
  end
end
