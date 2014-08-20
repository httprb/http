require 'spec_helper'

describe HTTP::Request do
  it 'includes HTTP::Headers::Mixin' do
    expect(described_class).to include HTTP::Headers::Mixin
  end

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

  describe '#redirect' do
    let(:headers)   { {:accept => 'text/html'} }
    let(:proxy)     { {:proxy_username => 'douglas', :proxy_password => 'adams'} }
    let(:body)      { 'The Ultimate Question' }
    let(:request)   { HTTP::Request.new(:post, 'http://example.com/', headers, proxy, body) }

    subject(:redirected) { request.redirect 'http://blog.example.com/' }

    describe '#uri' do
      subject { super().uri }
      it { is_expected.to eq URI.parse 'http://blog.example.com/' }
    end

    describe '#verb' do
      subject { super().verb }
      it { is_expected.to eq request.verb }
    end

    describe '#body' do
      subject { super().body }
      it { is_expected.to eq request.body }
    end

    describe '#proxy' do
      subject { super().proxy }
      it { is_expected.to eq request.proxy }
    end

    it 'presets new Host header' do
      expect(redirected['Host']).to eq 'blog.example.com'
    end

    context 'with relative URL given' do
      subject(:redirected) { request.redirect '/blog' }

      describe '#uri' do
        subject { super().uri }
        it { is_expected.to eq URI.parse 'http://example.com/blog' }
      end

      describe '#verb' do
        subject { super().verb }
        it { is_expected.to eq request.verb }
      end

      describe '#body' do
        subject { super().body }
        it { is_expected.to eq request.body }
      end

      describe '#proxy' do
        subject { super().proxy }
        it { is_expected.to eq request.proxy }
      end

      it 'keeps Host header' do
        expect(redirected['Host']).to eq 'example.com'
      end

      context 'with original URI having non-standard port' do
        let(:request) { HTTP::Request.new(:post, 'http://example.com:8080/', headers, proxy, body) }

        describe '#uri' do
          subject { super().uri }
          it { is_expected.to eq URI.parse 'http://example.com:8080/blog' }
        end
      end
    end

    context 'with relative URL that misses leading slash given' do
      subject(:redirected) { request.redirect 'blog' }

      describe '#uri' do
        subject { super().uri }
        it { is_expected.to eq URI.parse 'http://example.com/blog' }
      end

      describe '#verb' do
        subject { super().verb }
        it { is_expected.to eq request.verb }
      end

      describe '#body' do
        subject { super().body }
        it { is_expected.to eq request.body }
      end

      describe '#proxy' do
        subject { super().proxy }
        it { is_expected.to eq request.proxy }
      end

      it 'keeps Host header' do
        expect(redirected['Host']).to eq 'example.com'
      end

      context 'with original URI having non-standard port' do
        let(:request) { HTTP::Request.new(:post, 'http://example.com:8080/', headers, proxy, body) }

        describe '#uri' do
          subject { super().uri }
          it { is_expected.to eq URI.parse 'http://example.com:8080/blog' }
        end
      end
    end

    context 'with new verb given' do
      subject { request.redirect 'http://blog.example.com/', :get }

      describe '#verb' do
        subject { super().verb }
        it { is_expected.to be :get }
      end
    end
  end
end
