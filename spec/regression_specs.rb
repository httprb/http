require "spec_helper"

RSpec.describe "Regression testing" do
  describe "#248" do
    it "does not fails with github" do
      github_uri = "http://github.com/"
      expect { HTTP.get(github_uri).to_s }.not_to raise_error
    end

    it "does not failes ith googleapis" do
      google_uri = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
      expect { HTTP.get(google_uri).to_s }.not_to raise_error
    end
  end
end
