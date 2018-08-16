# frozen_string_literal: true

RSpec.describe HTTP::Features::Logging do
  subject(:feature) { HTTP::Features::Logging.new(:logger => logger) }
  let(:logger) { TestLogger.new }

  describe "logging the request" do
    let(:request) do
      HTTP::Request.new(
        :verb => :post,
        :uri => "https://example.com/",
        :headers => {:accept => "application/json"},
        :body => '{"hello": "world!"}'
      )
    end

    it "should log the request" do
      feature.wrap_request(request)

      expect(logger.output).to eq(
        [
          "> POST https://example.com/",
          <<~REQ.strip
            Accept: application/json
            Host: example.com
            User-Agent: http.rb/4.0.0.dev

            {"hello": "world!"}
          REQ
        ]
      )
    end
  end

  describe "logging the response" do
    let(:response) do
      HTTP::Response.new(
        :version => "1.1",
        :uri => "https://example.com",
        :status => 200,
        :headers => {:content_type => "application/json"},
        :body => '{"success": true}'
      )
    end

    it "should log the response" do
      feature.wrap_response(response)

      expect(logger.output).to eq(
        [
          "< 200 OK",
          <<~REQ.strip
            Content-Type: application/json

            {"success": true}
          REQ
        ]
      )
    end
  end

  class TestLogger
    attr_reader :output
    def initialize
      @output = []
    end

    %w[fatal error warn info debug].each do |level|
      define_method(level.to_sym) do |*args, &block|
        @output << (block ? block.call : args)
      end
    end
  end
end
