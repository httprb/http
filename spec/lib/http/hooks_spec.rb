# frozen_string_literal: true

require "support/dummy_server"

RSpec.describe HTTP, "hooks" do
  run_server(:dummy) { DummyServer.new }
  let(:client) { HTTP::Client.new }

  describe "before hook" do
    context "a hook that simply decorates the request" do
      before { client.before { |req| req.headers.add("X-Hook-Test", "1") } }

      subject(:response) { client.get dummy.endpoint + "/headers" }

      it "should pass the decorated request through" do
        request_headers = YAML.load(response.to_s)
        expect(request_headers["x-hook-test"]).to eq(["1"])
      end
    end

    context "muliple hooks" do
      let(:hook_calls) { [] }

      before do
        client.before do |req, opts|
          hook_calls << :first
          req.headers.add("X-Hook-Test-A", "1")
        end
        client.before do |req, opts|
          hook_calls << :second
          req.headers.add("X-Hook-Test-B", "2")
        end
      end

      subject(:response) { client.get dummy.endpoint + "/headers" }

      it "should pass all request changes through" do
        request_headers = YAML.load(response.to_s)
        expect(request_headers["x-hook-test-a"]).to eq(["1"])
        expect(request_headers["x-hook-test-b"]).to eq(["2"])
      end

      it "should call hooks in defined order" do
        response
        expect(hook_calls).to eq([:first, :second])
      end
    end
  end

  describe "after hook" do
    context "a hook that simply decorates the response" do
      before { client.after { |req, opts, res| res.headers.add("X-Hook-Test", "1") } }

      subject(:response) { client.get dummy.endpoint }

      it "should pass the decorated request through" do
        expect(response.headers["X-Hook-Test"]).to eq("1")
      end
    end

    context "muliple hooks" do
      let(:hook_calls) { [] }

      before do
        client.after do |req, opts, res|
          hook_calls << :first
          res.headers.add("X-Hook-Test-A", "1")
        end
        client.after do |req, opts, res|
          hook_calls << :second
          res.headers.add("X-Hook-Test-B", "2")
        end
      end

      subject(:response) { client.get dummy.endpoint }

      it "should pass all request changes through" do
        expect(response.headers["X-Hook-Test-A"]).to eq("1")
        expect(response.headers["X-Hook-Test-B"]).to eq("2")
      end

      it "should call hooks in reverse order" do
        response
        expect(hook_calls).to eq([:second, :first])
      end
    end

  end

  describe "around hook" do
    context "a hook that decorates the request and response" do
      before do
        client.around do |req, opts, &b|
          req.headers.add("X-Hook-Test-Req", "1")
          res = b.call req, opts
          res.headers.add("X-Hook-Test-Resp", "2")
          res
        end
      end

      subject(:response) { client.get dummy.endpoint + "/headers" }

      it "should pass request and response changes through" do
        request_headers = YAML.load(response.to_s)
        expect(request_headers["x-hook-test-req"]).to eq(["1"])
        expect(response.headers["X-Hook-Test-Resp"]).to eq("2")
      end
    end

    context "nested hooks" do
      let(:hook_calls) { [] }

      let(:inner_hook) do
        lambda do |req, opts, &b|
          hook_calls << :inner_before
          res = b.call req, opts
          res.headers["X-Inner-Hook"] = 1
          hook_calls << :inner_after
          res
        end
      end

      let(:outer_hook) do
        lambda do |req, opts, &b|
          hook_calls << :outer_before
          res = b.call req, opts
          res.headers["X-Outer-Hook"] = 1
          hook_calls << :outer_after
          res
        end
      end

      before do
        client.around(&inner_hook)
        client.around(&outer_hook)
      end

      subject(:response) { client.get dummy.endpoint + "/headers" }

      it "should pass all request changes through" do
        expect(response.headers["X-Inner-Hook"]).to eq("1")
        expect(response.headers["X-Outer-Hook"]).to eq("1")
      end

      it "should call the earliest defined hooks as the innermost hook" do
        response
        expect(hook_calls).to eq([:outer_before, :inner_before, :inner_after, :outer_after])
      end
    end
  end
end
