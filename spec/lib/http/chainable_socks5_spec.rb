# frozen_string_literal: true

RSpec.describe HTTP::Chainable do
  describe "via_socks5" do
    let(:proxy_address) { "127.0.0.1" }
    let(:proxy_port) { 8080 }
    let(:proxy_username) { "username" }
    let(:proxy_password) { "password" }

    it "creates a client with SOCKS5 proxy" do
      client = HTTP.via_socks5(proxy_address, proxy_port)
      expect(client.default_options.proxy).to eq(
        proxy_address: proxy_address,
        proxy_port:    proxy_port,
        proxy_type:    :socks5
      )
    end

    it "creates a client with authenticated SOCKS5 proxy" do
      client = HTTP.via_socks5(proxy_address, proxy_port, proxy_username, proxy_password)
      expect(client.default_options.proxy).to eq(
        proxy_address:  proxy_address,
        proxy_port:     proxy_port,
        proxy_username: proxy_username,
        proxy_password: proxy_password,
        proxy_type:     :socks5
      )
    end

    it "raises an error with invalid proxy parameters" do
      expect { HTTP.via_socks5 }.to raise_error(HTTP::RequestError)
      expect { HTTP.via_socks5(proxy_address) }.to raise_error(HTTP::RequestError)
    end
  end
end
