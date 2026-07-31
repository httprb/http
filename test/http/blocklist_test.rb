# frozen_string_literal: true

require "test_helper"

class HTTPBlocklistTest < Minitest::Test
  cover "HTTP::Blocklist*"

  LOOPBACK_V4 = IPAddr.new("127.0.0.0/8")

  DENY_LOOPBACK = lambda(&:loopback?)

  # .new

  def test_new_returns_a_given_blocklist_unchanged
    blocklist = HTTP::Blocklist.new(["localhost"])

    assert_same blocklist, HTTP::Blocklist.new(blocklist)
  end

  def test_new_accepts_entries_that_are_not_arrays
    assert HTTP::Blocklist.new("localhost").blocked_host?("localhost")
    assert HTTP::Blocklist.new(Set["localhost"]).blocked_host?("localhost")
  end

  # #blocked_host?

  def test_blocked_host_matches_the_host_and_its_subdomains
    blocklist = HTTP::Blocklist.new(["example.com"])

    assert blocklist.blocked_host?("example.com")
    assert blocklist.blocked_host?("api.example.com")
    refute blocklist.blocked_host?("notexample.com")
    refute blocklist.blocked_host?("example.org")
  end

  def test_blocked_host_ignores_case_and_a_trailing_dot
    blocklist = HTTP::Blocklist.new(["Example.COM"])

    assert blocklist.blocked_host?("API.example.com.")
  end

  def test_blocked_host_only_considers_string_entries
    blocklist = HTTP::Blocklist.new([IPAddr.new("127.0.0.1"), "127.0.0.2"])

    refute blocklist.blocked_host?("127.0.0.1")
    assert blocklist.blocked_host?("127.0.0.2")
  end

  # #blocked_address?

  def test_blocked_address_matches_addresses_and_ranges
    blocklist = HTTP::Blocklist.new([IPAddr.new("169.254.169.254"), LOOPBACK_V4])

    assert blocklist.blocked_address?(IPAddr.new("169.254.169.254"))
    assert blocklist.blocked_address?(IPAddr.new("127.0.0.1"))
    refute blocklist.blocked_address?(IPAddr.new("93.184.216.34"))
  end

  def test_blocked_address_compares_within_an_address_family
    blocklist = HTTP::Blocklist.new([LOOPBACK_V4, IPAddr.new("::1")])

    assert blocklist.blocked_address?(IPAddr.new("::1"))
    assert blocklist.blocked_address?(IPAddr.new("::ffff:127.0.0.1"))
    refute blocklist.blocked_address?(IPAddr.new("::2"))
  end

  def test_blocked_address_only_considers_ipaddr_entries
    blocklist = HTTP::Blocklist.new(["localhost"])

    refute blocklist.blocked_address?(IPAddr.new("127.0.0.1"))
  end

  def test_blocked_address_consults_deny_and_returns_a_boolean
    blocklist = HTTP::Blocklist.new(deny: DENY_LOOPBACK)

    assert blocklist.blocked_address?(IPAddr.new("127.0.0.1"))
    assert_same false, blocklist.blocked_address?(IPAddr.new("93.184.216.34"))
    assert_same false, HTTP::Blocklist.new([]).blocked_address?(IPAddr.new("127.0.0.1"))
  end

  def test_blocked_address_blocks_when_either_entries_or_deny_match
    entries_only = HTTP::Blocklist.new([LOOPBACK_V4], deny: ->(_address) { false })
    deny_only    = HTTP::Blocklist.new([IPAddr.new("10.0.0.0/8")], deny: DENY_LOOPBACK)

    assert entries_only.blocked_address?(IPAddr.new("127.0.0.1"))
    assert deny_only.blocked_address?(IPAddr.new("127.0.0.1"))
  end

  def test_blocked_address_gives_deny_the_native_form_of_a_mapped_address
    seen = []
    blocklist = HTTP::Blocklist.new(deny: ->(address) { seen << address.to_s and false })

    blocklist.blocked_address?(IPAddr.new("::ffff:127.0.0.1"))

    assert_equal ["127.0.0.1"], seen
  end

  # #validate!

  def test_validate_returns_the_first_resolved_address
    blocklist = HTTP::Blocklist.new([IPAddr.new("10.0.0.0/8")])
    resolved  = [Addrinfo.ip("93.184.216.34"), Addrinfo.ip("93.184.216.35")]

    assert_equal "127.0.0.1", blocklist.validate!("127.0.0.1")

    Addrinfo.stub(:getaddrinfo, resolved) do
      assert_equal "93.184.216.34", blocklist.validate!("example.com")
    end
  end

  def test_validate_raises_for_a_blocked_hostname_without_resolving_it
    blocklist = HTTP::Blocklist.new(["blocked.invalid"])

    err = assert_raises(HTTP::BlockedHostError) { blocklist.validate!("api.blocked.invalid") }
    assert_includes err.message, "api.blocked.invalid"
  end

  def test_validate_raises_when_any_resolved_address_is_blocked
    blocklist = HTTP::Blocklist.new([LOOPBACK_V4])
    resolved  = [Addrinfo.ip("93.184.216.34"), Addrinfo.ip("127.0.0.1")]

    Addrinfo.stub(:getaddrinfo, resolved) do
      err = assert_raises(HTTP::BlockedHostError) { blocklist.validate!("example.com") }
      assert_includes err.message, "example.com"
      assert_includes err.message, "127.0.0.1"
    end
  end

  def test_validate_raises_when_deny_blocks_a_resolved_address
    blocklist = HTTP::Blocklist.new(deny: DENY_LOOPBACK)

    assert_raises(HTTP::BlockedHostError) { blocklist.validate!("127.0.0.1") }
  end

  def test_validate_does_not_warn_and_raises_a_non_retriable_error
    blocklist = HTTP::Blocklist.new([LOOPBACK_V4])
    err = nil

    warning = capture_warning do
      err = assert_raises(HTTP::BlockedHostError) { blocklist.validate!("127.0.0.1") }
    end

    assert_empty warning
    refute_kind_of HTTP::ConnectionError, err
  end

  # #warn_proxy_incompatible

  def test_warn_proxy_incompatible_warns_once
    blocklist = HTTP::Blocklist.new([LOOPBACK_V4])

    warning = capture_warning do
      blocklist.warn_proxy_incompatible
      blocklist.warn_proxy_incompatible
    end

    assert_includes warning, "proxy"
    assert_equal 1, warning.lines.count
  end
end
