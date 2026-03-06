# frozen_string_literal: true

require "test_helper"

describe "Regression testing" do
  describe "#248" do
    it "does not fail with github" do
      github_uri = "http://github.com/"
      HTTP.get(github_uri).to_s
    end

    it "does not fail with googleapis" do
      google_uri = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
      HTTP.get(google_uri).to_s
    end
  end

  describe "#422" do
    it "reads body when 200 OK response contains Upgrade header" do
      res = HTTP.get("https://httpbin.org/response-headers?Upgrade=h2,h2c")
      parsed = res.parse(:json)

      assert_includes parsed, "Upgrade"
      assert_equal "h2,h2c", parsed["Upgrade"]
    end
  end
end
