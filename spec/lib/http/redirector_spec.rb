RSpec.describe HTTP::Redirector do
  def simple_response(status, body = "", headers = {})
    HTTP::Response.new(status, "1.1", headers, body)
  end

  def redirect_response(location, status)
    simple_response status, "", "Location" => location
  end

  let(:max_hops)       { 5 }
  subject(:redirector) { described_class.new max_hops }
  let(:options) do
    {
      :max_hops => 5,
      :strict => true
    }
  end
  subject(:strict_redirector) { described_class.new options }

  context "following 300 redirect" do
    let(:orig_request)  { HTTP::Request.new :post, "http://www.example.com/" }
    let(:orig_response) { redirect_response "http://example.com/", 300 }

    it "follows without changing verb" do
      redirector.perform(orig_request, orig_response) do |request|
        expect(request.verb).to be orig_request.verb
        simple_response 200
      end
    end
  end

  context "following 301 redirect" do
    context "upon GET request" do
      let(:orig_request)  { HTTP::Request.new :get, "http://www.example.com/" }
      let(:orig_response) { redirect_response "http://example.com/", 301 }

      it "follows without changing verb" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be orig_request.verb
          simple_response 200
        end
      end
    end

    context "upon POST request in strict mode" do
      let(:orig_request)   { HTTP::Request.new :post, "http://www.example.com/" }
      let(:orig_response)  { redirect_response "http://example.com/", 301 }

      it "raises StateError" do
        expect { strict_redirector.perform(orig_request, orig_response) }.to raise_error HTTP::StateError
      end
    end

    context "upon post request in non-strict mode" do
      let(:orig_request)   { HTTP::Request.new :post, "http://www.example.com/" }
      let(:orig_response)  { redirect_response "http://example.com/", 301 }

      it "redirects to a GET request" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be :get
          simple_response 200
        end
      end
    end
  end

  context "following 302 redirect" do
    context "upon GET request" do
      let(:orig_request)  { HTTP::Request.new :get, "http://www.example.com/" }
      let(:orig_response) { redirect_response "http://example.com/", 302 }

      it "follows without changing verb" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be orig_request.verb
          simple_response 200
        end
      end
    end

    context "upon POST request in strict mode" do
      let(:orig_request)   { HTTP::Request.new :post, "http://www.example.com/" }
      let(:orig_response)  { redirect_response "http://example.com/", 302 }

      it "raises StateError" do
        expect { strict_redirector.perform(orig_request, orig_response) }.to raise_error HTTP::StateError
      end
    end

    context "upon post request in non-strict mode" do
      let(:orig_request)   { HTTP::Request.new :post, "http://www.example.com/" }
      let(:orig_response)  { redirect_response "http://example.com/", 302 }

      it "redirects to a GET request" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be :get
          simple_response 200
        end
      end
    end
  end

  context "following 303 redirect" do
    context "upon GET request" do
      let(:orig_request)  { HTTP::Request.new :get, "http://www.example.com/" }
      let(:orig_response) { redirect_response "http://example.com/", 303 }

      it "follows without changing verb" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be orig_request.verb
          simple_response 200
        end
      end
    end

    context "upon HEAD request" do
      let(:orig_request)  { HTTP::Request.new :head, "http://www.example.com/" }
      let(:orig_response) { redirect_response "http://example.com/", 303 }

      it "follows without changing verb" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be :get
          simple_response 200
        end
      end
    end

    context "upon POST request in strict mode" do
      let(:orig_request)   { HTTP::Request.new :post, "http://www.example.com/" }
      let(:orig_response)  { redirect_response "http://example.com/", 303 }

      it "raises StateError" do
        expect { strict_redirector.perform(orig_request, orig_response) }.to raise_error HTTP::StateError
      end
    end

    context "upon post request in non-strict mode" do
      let(:orig_request)   { HTTP::Request.new :post, "http://www.example.com/" }
      let(:orig_response)  { redirect_response "http://example.com/", 303 }

      it "redirects to a GET request" do
        redirector.perform(orig_request, orig_response) do |request|
          expect(request.verb).to be :get
          simple_response 200
        end
      end
    end
  end

  context "following 307 redirect" do
    let(:orig_request)  { HTTP::Request.new :post, "http://www.example.com/" }
    let(:orig_response) { redirect_response "http://example.com/", 307 }

    it "follows without changing verb" do
      redirector.perform(orig_request, orig_response) do |request|
        expect(request.verb).to be orig_request.verb
        simple_response 200
      end
    end
  end

  context "following 308 redirect" do
    let(:orig_request)  { HTTP::Request.new :post, "http://www.example.com/" }
    let(:orig_response) { redirect_response "http://example.com/", 308 }

    it "follows without changing verb" do
      redirector.perform(orig_request, orig_response) do |request|
        expect(request.verb).to be orig_request.verb
        simple_response 200
      end
    end
  end
end
