# frozen_string_literal: true

RSpec.describe HTTP::Request::Proxy do
  let(:request_uri) { HTTP::URI::NORMALIZER.call("http://www.example.org") }
  let(:http_proxy_uri) { "http://douglas:adams@proxy.example.com:8001/" }
  let(:proxy_params) { nil }
  subject { described_class.new(proxy_params, request_uri) }

  describe "#initialize" do
    context "when no proxy are set" do
      it "does not raise an error" do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe "#available?" do
    context "when no proxy are set" do
      it "returns false" do
        expect(subject.available?).to be_falsey
      end
    end

    context "when proxy is set by the user" do
      let(:proxy_params) { {:proxy_address => "proxy.example.com", :proxy_port => 8001} }

      it "returns true" do
        expect(subject.available?).to be_truthy
      end
    end

    context "when proxy is set by env variables" do
      it "returns true" do
        stub_const("ENV", "http_proxy" => http_proxy_uri)

        expect(subject.available?).to be_truthy
      end

      it "returns false when proxy schema is different to request_uri" do
        stub_const("ENV", "https_proxy" => http_proxy_uri)

        expect(subject.available?).to be_falsey
      end
    end

    context "when no_proxy is set by env variable" do
      it "returns false when no_proxy matches request_uri" do
        stub_const("ENV", "http_proxy" => http_proxy_uri, "no_proxy" => "example.org")

        expect(subject.available?).to be_falsey
      end
    end
  end

  describe "#authenticated?" do
    context "when no credentials are set" do
      it "returns false" do
        expect(subject.authenticated?).to be_falsey
      end
    end

    context "when credentials are set by the user" do
      let(:proxy_params) { {:proxy_username => "douglas", :proxy_password => "adams"} }

      it "returns true" do
        expect(subject.authenticated?).to be_truthy
      end
    end

    context "when credentials are set by env variables" do
      it "returns true" do
        stub_const("ENV", "http_proxy" => http_proxy_uri)

        expect(subject.authenticated?).to be_truthy
      end

      it "returns false when no_proxy matches request_uri" do
        stub_const("ENV", "http_proxy" => http_proxy_uri, "no_proxy" => "example.org")

        expect(subject.authenticated?).to be_falsey
      end

      it "returns false when proxy schema is different to request_uri" do
        stub_const("ENV", "https_proxy" => http_proxy_uri)

        expect(subject.authenticated?).to be_falsey
      end
    end
  end

  describe "#include_headers?" do
    context "when no extra headers are set by the user" do
      it "returns false" do
        expect(subject.include_headers?).to be_falsey
      end
    end

    context "when extra headers are set by the user" do
      let(:proxy_params) { {:proxy_headers => {"X-Forwarded-For" => "127.0.0.1"}} }

      it "returns true" do
        expect(subject.include_headers?).to be_truthy
      end
    end
  end

  describe "#username" do
    context "when no credentials are set" do
      it "returns nil" do
        expect(subject.username).to be_nil
      end
    end

    context "when credentials are set by the user" do
      let(:proxy_params) { {:proxy_username => "douglas", :proxy_password => "adams"} }

      it "returns the username set by the user" do
        expect(subject.username).to eq("douglas")
      end
    end

    context "when credentials are set by env variables" do
      it "returns the username set by the proxy env variable" do
        stub_const("ENV", "http_proxy" => http_proxy_uri)

        expect(subject.username).to eq("douglas")
      end

      it "returns nil when proxy schema is different to request_uri" do
        stub_const("ENV", "https_proxy" => http_proxy_uri)

        expect(subject.password).to be_nil
      end

      it "returns nil when no_proxy matches request_uri" do
        stub_const("ENV", "http_proxy" => http_proxy_uri, "no_proxy" => "example.org")

        expect(subject.username).to be_nil
      end
    end
  end

  describe "#password" do
    context "when no credentials are set" do
      it "returns nil" do
        expect(subject.password).to be_nil
      end
    end

    context "when credentials are set by the user" do
      let(:proxy_params) { {:proxy_username => "douglas", :proxy_password => "adams"} }

      it "returns the username set by the user" do
        expect(subject.password).to eq("adams")
      end
    end

    context "when credentials are set by env variables" do
      it "returns the username set by the proxy env variable" do
        stub_const("ENV", "http_proxy" => http_proxy_uri)

        expect(subject.password).to eq("adams")
      end

      it "returns nil when proxy schema is different to request_uri" do
        stub_const("ENV", "https_proxy" => http_proxy_uri)

        expect(subject.password).to be_nil
      end

      it "returns nil when no_proxy matches request_uri" do
        stub_const("ENV", "http_proxy" => http_proxy_uri, "no_proxy" => "example.org")

        expect(subject.password).to be_nil
      end
    end
  end

  describe "#address" do
    context "when not set" do
      it "returns nil" do
        expect(subject.address).to be_nil
      end
    end

    context "when set by the user" do
      let(:proxy_params) { {:proxy_address => "proxy.example.com", :proxy_port => "8001"} }

      it "returns the proxy address set by the user" do
        expect(subject.address).to eq("proxy.example.com")
      end
    end

    context "when proxy is set by env variables" do
      it "returns the proxy address set by env variables" do
        stub_const("ENV", "http_proxy" => http_proxy_uri)

        expect(subject.address).to eq("proxy.example.com")
      end

      it "returns nil when proxy schema is different to request_uri" do
        stub_const("ENV", "https_proxy" => http_proxy_uri)

        expect(subject.address).to be_nil
      end

      it "returns nil when no_proxy matches request_uri" do
        stub_const("ENV", "http_proxy" => http_proxy_uri, "no_proxy" => "example.org")

        expect(subject.address).to be_nil
      end
    end
  end

  describe "#port" do
    context "when not set" do
      it "returns nil" do
        expect(subject.port).to be_nil
      end
    end

    context "when set by the user" do
      let(:proxy_params) { {:proxy_address => "proxy.example.com", :proxy_port => 8001} }

      it "returns the proxy address set by the user" do
        expect(subject.port).to eq(8001)
      end
    end

    context "when proxy is set by env variables" do
      it "returns the proxy address set by env variables" do
        stub_const("ENV", "http_proxy" => http_proxy_uri)

        expect(subject.port).to eq(8001)
      end

      it "returns nil when proxy schema is different to request_uri" do
        stub_const("ENV", "https_proxy" => http_proxy_uri)

        expect(subject.port).to be_nil
      end

      it "returns nil when no_proxy matches request_uri" do
        stub_const("ENV", "http_proxy" => http_proxy_uri, "no_proxy" => "example.org")

        expect(subject.port).to be_nil
      end
    end
  end

  describe "#headers" do
    context "when not set" do
      it "returns nil" do
        expect(subject.headers).to eq(nil)
      end
    end

    context "when set by the user" do
      let(:proxy_params) { {:proxy_headers => {"X-Forwarded-For" => "127.0.0.1"}} }

      it "returns the extra headers set by the user" do
        expect(subject.headers).to eq("X-Forwarded-For" => "127.0.0.1")
      end
    end
  end
end
