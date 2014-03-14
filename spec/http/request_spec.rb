require 'spec_helper'

describe HTTP::Request do
  it 'requires URI to have scheme part' do
    expect { HTTP::Request.new(:get, 'example.com/') }.to \
      raise_error(HTTP::Request::UnsupportedSchemeError)
  end

  it 'provides a #scheme accessor' do
    request = HTTP::Request.new(:get, 'http://example.com/')
    expect(request.scheme).to eq(:http)
  end

  describe 'headers' do
    subject { HTTP::Request.new(:get, 'http://example.com/', :accept => 'text/html') }

    it 'sets explicit headers' do
      expect(subject['Accept']).to eq('text/html')
    end

    it 'sets implicit headers' do
      expect(subject['Host']).to eq('example.com')
    end

    it 'provides a #headers accessor' do
      expect(subject.headers).to eq('Accept' => 'text/html', 'Host' => 'example.com')
    end

    it 'provides a #verb accessor' do
      expect(subject.verb).to eq(:get)
    end

    it 'provides a #method accessor that outputs a deprecation warning and returns the verb' do
      warning = capture_warning do
        expect(subject.method).to eq(subject.verb)
      end
      expect(warning).to match(/\[DEPRECATION\] HTTP::Request#method is deprecated\. Use #verb instead\. For Object#method, use #__method__\.$/)
    end

    it 'provides a #__method__ method that delegates to Object#method' do
      expect(subject.__method__(:verb)).to be_a(Method)
    end
  end

  describe 'redirect' do
    subject {
      HTTP::Request.new(:post, 'http://example.com/',
        { :accept => 'text/html' }, {}, 'test')
    }

    it 'returns a new request to the new uri' do
      redirected = subject.redirect('http://example.com/redirect')
      expect(redirected.uri.to_s).to eq('http://example.com/redirect')
      expect(redirected.verb).to eq(:post)
      expect(redirected.body).to eq('test')
      expect(redirected.headers['Host']).to eq('example.com')
    end
  end
end
