# frozen_string_literal: true

require "test_helper"

class HTTPOptionsBlocklistTest < Minitest::Test
  cover "HTTP::Options*"

  def test_blocklist_coerces_option_values
    existing = HTTP::Blocklist.new(["localhost"])

    assert_nil HTTP::Options.new.blocklist
    assert_kind_of HTTP::Blocklist, HTTP::Options.new(blocklist: ["localhost"]).blocklist
    assert_same existing, HTTP::Options.new(blocklist: existing).blocklist
  end

  def test_blocklist_accepts_a_hash_of_entries_and_deny
    opts = HTTP::Options.new(
      blocklist: { entries: ["localhost"], deny: lambda(&:loopback?) }
    )

    deny_only = HTTP::Options.new(blocklist: { deny: lambda(&:loopback?) })

    assert opts.blocklist.blocked_host?("localhost")
    assert opts.blocklist.blocked_address?(IPAddr.new("127.0.0.1"))
    assert deny_only.blocklist.blocked_address?(IPAddr.new("127.0.0.1"))
  end

  def test_blocklist_raises_for_an_unknown_hash_key
    assert_raises(ArgumentError) { HTTP::Options.new(blocklist: { entries: [], allow: :nope }) }
  end

  def test_with_blocklist_replaces_without_modifying_the_original
    opts   = HTTP::Options.new
    result = opts.with_blocklist(["example.com"]).with_blocklist(["example.org"])

    assert_nil opts.blocklist
    assert result.blocklist.blocked_host?("example.org")
    refute result.blocklist.blocked_host?("example.com")
  end

  def test_blocklist_survives_a_merge_with_per_request_options
    opts = HTTP::Options.new(blocklist: ["localhost"]).merge(follow: true)

    assert opts.blocklist.blocked_host?("localhost")
  end
end
