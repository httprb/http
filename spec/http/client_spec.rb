require 'spec_helper'

describe HTTP::Client do
  StubbedClient = Class.new(HTTP::Client) do
    def initialize(options = {})
      @stubs = options.delete(:stubs) || {}
      super(options)
    end

    def perform(request, options)
      @stubs[request.uri.to_s] || super(request, options)
    end
  end

  def redirect_response(location, status = 302)
    HTTP::Response.new(status, '1.1', {'Location' => location}, '')
  end

  def simple_response(body, status = 200)
    HTTP::Response.new(status, '1.1', {}, body)
  end

  describe 'following redirects' do
    it 'prepends previous request uri scheme and host if needed' do
      client = StubbedClient.new(:follow => true, :stubs  => {
        'http://example.com/'           => redirect_response('/index'),
        'http://example.com/index'      => redirect_response('/index.html'),
        'http://example.com/index.html' => simple_response('OK')
      })
      expect(client.get('http://example.com/').response.body).to eq 'OK'
    end
  end
end
