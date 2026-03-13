# frozen_string_literal: true

require "test_helper"

describe HTTP::VERSION do
  cover "HTTP::VERSION*"

  it "is a string" do
    assert_kind_of String, HTTP::VERSION
  end

  it "follows semantic versioning" do
    assert_match(/\A\d+\.\d+\.\d+/, HTTP::VERSION)
  end
end
