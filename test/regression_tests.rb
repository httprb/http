# frozen_string_literal: true

require "test_helper"

class RegressionTest < Minitest::Test
  # #248

  def test_248_does_not_fail_with_github
    github_uri = "http://github.com/"
    HTTP.get(github_uri).to_s
  end

  def test_248_does_not_fail_with_googleapis
    google_uri = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
    HTTP.get(google_uri).to_s
  end

  # #422

  def test_422_reads_body_when_200_ok_response_contains_upgrade_header
    res = HTTP.get("https://httpbin.org/response-headers?Upgrade=h2,h2c")
    parsed = res.parse(:json)

    assert_includes parsed, "Upgrade"
    assert_equal "h2,h2c", parsed["Upgrade"]
  end
end
