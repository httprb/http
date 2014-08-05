require 'spec_helper'

describe HTTP::Request do
  let(:headers)     { {:accept => 'text/html'} }
  let(:request_uri) { 'http://example.com/' }

  subject(:request) { HTTP::Request.new(:get, request_uri, headers) }

  it 'includes HTTP::Headers::Mixin' do
    expect(described_class).to include HTTP::Headers::Mixin
  end

  it 'requires URI to have scheme part' do
    expect { HTTP::Request.new(:get, 'example.com/') }.to \
      raise_error(HTTP::Request::UnsupportedSchemeError)
  end

  it 'provides a #scheme accessor' do
    expect(request.scheme).to eq(:http)
  end

  it 'sets given headers' do
    expect(subject['Accept']).to eq('text/html')
  end

  describe 'Host header' do
    subject { request['Host'] }

    context 'was not given' do
      it { is_expected.to eq 'example.com' }

      context 'and request URI has non-standard port' do
        let(:request_uri) { 'http://example.com:3000/' }
        it { is_expected.to eq 'example.com:3000' }
      end
    end

    context 'was explicitly given' do
      before { headers[:host] = 'github.com' }
      it { is_expected.to eq 'github.com' }
    end
  end

  describe 'User-Agent header' do
    subject { request['User-Agent'] }

    context 'was not given' do
      it { is_expected.to eq HTTP::Request::USER_AGENT }
    end

    context 'was explicitly given' do
      before { headers[:user_agent] = 'MrCrawly/123' }
      it { is_expected.to eq 'MrCrawly/123' }
    end
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

  describe '#redirect' do
    let(:headers)   { {:accept => 'text/html'} }
    let(:proxy)     { {:proxy_username => 'douglas', :proxy_password => 'adams'} }
    let(:body)      { 'The Ultimate Question' }
    let(:request)   { HTTP::Request.new(:post, 'http://example.com/', headers, proxy, body) }

    subject(:redirected) { request.redirect 'http://blog.example.com/' }

    its(:uri)     { should eq URI.parse 'http://blog.example.com/' }

    its(:verb)    { should eq request.verb }
    its(:body)    { should eq request.body }
    its(:proxy)   { should eq request.proxy }

    it 'presets new Host header' do
      expect(redirected['Host']).to eq 'blog.example.com'
    end

    context 'with schema-less absolute URL given' do
      subject(:redirected) { request.redirect '//another.example.com/blog' }

      its(:uri)     { should eq URI.parse 'http://another.example.com/blog' }

      its(:verb)    { should eq request.verb }
      its(:body)    { should eq request.body }
      its(:proxy)   { should eq request.proxy }

      it 'presets new Host header' do
        expect(redirected['Host']).to eq 'another.example.com'
      end
    end

    context 'with relative URL given' do
      subject(:redirected) { request.redirect '/blog' }

      its(:uri)     { should eq URI.parse 'http://example.com/blog' }

      its(:verb)    { should eq request.verb }
      its(:body)    { should eq request.body }
      its(:proxy)   { should eq request.proxy }

      it 'keeps Host header' do
        expect(redirected['Host']).to eq 'example.com'
      end

      context 'with original URI having non-standard port' do
        let(:request) { HTTP::Request.new(:post, 'http://example.com:8080/', headers, proxy, body) }
        its(:uri)     { should eq URI.parse 'http://example.com:8080/blog' }
      end
    end

    context 'with relative URL that misses leading slash given' do
      subject(:redirected) { request.redirect 'blog' }

      its(:uri)     { should eq URI.parse 'http://example.com/blog' }

      its(:verb)    { should eq request.verb }
      its(:body)    { should eq request.body }
      its(:proxy)   { should eq request.proxy }

      it 'keeps Host header' do
        expect(redirected['Host']).to eq 'example.com'
      end

      context 'with original URI having non-standard port' do
        let(:request) { HTTP::Request.new(:post, 'http://example.com:8080/', headers, proxy, body) }
        its(:uri)     { should eq URI.parse 'http://example.com:8080/blog' }
      end
    end

    context 'with new verb given' do
      subject { request.redirect 'http://blog.example.com/', :get }
      its(:verb) { should be :get }
    end
  end
end
