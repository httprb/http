require 'spec_helper'

describe HTTP::Request do
  describe "headers" do
    subject { HTTP::Request.new(:get, "http://example.com/", :accept => "text/html") }

    it "sets explicit headers" do
      expect(subject["Accept"]).to eq("text/html")
    end

    it "sets implicit headers" do
      expect(subject["Host"]).to eq("example.com")
    end

    it "provides a #headers accessor" do
      expect(subject.headers).to eq("Accept" => "text/html", "Host" => "example.com")
    end
  end

  describe '#redirect' do
    let(:headers)   { {:accept => 'text/html'} }
    let(:proxy)     { {:proxy_username => 'douglas', :proxy_password => 'adams'} }
    let(:body)      { 'The Ultimate Question' }
    let(:request)   { HTTP::Request.new(:post, 'http://example.com/', headers, proxy, body) }

    subject(:redirected) { request.redirect 'http://blog.example.com/' }

    its(:uri)     { should eq URI.parse 'http://blog.example.com/' }

    its(:method)  { should eq request.method }
    its(:body)    { should eq request.body }
    its(:proxy)   { should eq request.proxy }

    it 'presets new Host header' do
      expect(redirected.headers['Host']).to eq 'blog.example.com'
    end

    context 'with relative URL given' do
      subject(:redirected) { request.redirect '/blog' }

      its(:uri)     { should eq URI.parse 'http://example.com/blog' }

      its(:method)  { should eq request.method }
      its(:body)    { should eq request.body }
      its(:proxy)   { should eq request.proxy }

      it 'keeps Host header' do
        expect(redirected.headers['Host']).to eq 'example.com'
      end
    end

    context 'with relative URL that misses leading slash given' do
      subject(:redirected) { request.redirect 'blog' }

      its(:uri)     { should eq URI.parse 'http://example.com/blog' }

      its(:method)  { should eq request.method }
      its(:body)    { should eq request.body }
      its(:proxy)   { should eq request.proxy }

      it 'keeps Host header' do
        expect(redirected.headers['Host']).to eq 'example.com'
      end
    end
  end
end
