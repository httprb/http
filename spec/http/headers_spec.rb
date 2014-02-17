require 'spec_helper'

describe HTTP::Headers do
  subject(:headers) { described_class.new }

  describe '.new' do
    it 'accepts any object that respond to :to_hash' do
      x = HTTP::Headers.new Struct.new(:to_hash).new('accept' => 'json')
      expect(x['Accept']).to eq 'json'
    end
  end

  describe '#[]' do
    it 'normalizes header name' do
      headers['Content-Type'] = 'text/plain'
      expect(headers[:content_type]).to eq 'text/plain'
    end
  end

  describe '#[]=' do
    it 'normalizes header name' do
      headers[:content_type] = 'text/plain'
      expect(headers).to include 'Content-Type'
    end

    it 'groups duplicate header values into Arrays' do
      headers['set-cookie'] = 'a=b;'
      headers['set-cookie'] = 'c=d;'
      headers['set-cookie'] = 'e=f;'

      expect(headers).to eq('Set-Cookie' => ['a=b;', 'c=d;', 'e=f;'])
    end

    it 'respects if additional value is Array' do
      headers['set-cookie'] = 'a=b;'
      headers['set-cookie'] = ['c=d;', 'e=f;']

      expect(headers).to eq('Set-Cookie' => ['a=b;', 'c=d;', 'e=f;'])
    end
  end
end
