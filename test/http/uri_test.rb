# frozen_string_literal: true

require "test_helper"
require "addressable/uri"

class HTTPURITest < Minitest::Test
  cover "HTTP::URI*"

  def example_ipv6_address
    "2606:2800:220:1:248:1893:25c8:1946"
  end

  def example_http_uri_string
    "http://example.com"
  end

  def example_https_uri_string
    "https://example.com"
  end

  def example_ipv6_uri_string
    "https://[#{example_ipv6_address}]"
  end

  def http_uri
    @http_uri ||= HTTP::URI.parse(example_http_uri_string)
  end

  def https_uri
    @https_uri ||= HTTP::URI.parse(example_https_uri_string)
  end

  def ipv6_uri
    @ipv6_uri ||= HTTP::URI.parse(example_ipv6_uri_string)
  end

  def test_knows_uri_schemes
    assert_equal "http", http_uri.scheme
    assert_equal "https", https_uri.scheme
  end

  def test_sets_default_ports_for_http_uris
    assert_equal 80, http_uri.port
  end

  def test_sets_default_ports_for_https_uris
    assert_equal 443, https_uri.port
  end

  def test_host_strips_brackets_from_ipv6_addresses
    assert_equal "2606:2800:220:1:248:1893:25c8:1946", ipv6_uri.host
  end

  def test_normalized_host_strips_brackets_from_ipv6_addresses
    assert_equal "2606:2800:220:1:248:1893:25c8:1946", ipv6_uri.normalized_host
  end

  def test_inspect_returns_a_human_readable_representation
    assert_match(%r{#<HTTP::URI:0x\h+ URI:http://example\.com>}, http_uri.inspect)
  end

  def test_host_assignment_updates_cached_values_for_host_and_normalized_host
    uri = HTTP::URI.parse("http://example.com")

    assert_equal "example.com", uri.host
    assert_equal "example.com", uri.normalized_host

    uri.host = "[#{example_ipv6_address}]"

    assert_equal example_ipv6_address, uri.host
    assert_equal example_ipv6_address, uri.normalized_host
  end

  def test_host_assignment_ensures_ipv6_addresses_are_bracketed_in_the_raw_host
    uri = HTTP::URI.parse("http://example.com")

    assert_equal "example.com", uri.host
    assert_equal "example.com", uri.normalized_host

    uri.host = example_ipv6_address

    assert_equal example_ipv6_address, uri.host
    assert_equal example_ipv6_address, uri.normalized_host
    assert_equal "[#{example_ipv6_address}]", uri.instance_variable_get(:@raw_host)
  end

  def test_form_encode_encodes_key_value_pairs
    assert_equal "foo=bar&baz=quux", HTTP::URI.form_encode({ foo: "bar", baz: "quux" })
  end

  def test_initialize_raises_argument_error_for_positional_argument
    assert_raises(ArgumentError) { HTTP::URI.new(42) }
  end

  def test_http_predicate_returns_true_for_http_uris
    assert_predicate http_uri, :http?
  end

  def test_http_predicate_returns_false_for_https_uris
    refute_predicate https_uri, :http?
  end

  def test_eql_returns_true_for_equivalent_uris
    assert http_uri.eql?(HTTP::URI.parse(example_http_uri_string))
  end

  def test_eql_returns_false_for_non_uri_objects
    refute http_uri.eql?("http://example.com")
  end

  def test_hash_returns_an_integer
    assert_kind_of Integer, http_uri.hash
  end

  def test_dup_doesnt_share_internal_value_between_duplicates
    uri = HTTP::URI.parse("http://example.com")
    duplicated_uri = uri.dup
    duplicated_uri.host = "example.org"

    assert_equal "http://example.org", duplicated_uri.to_s
    assert_equal "http://example.com", uri.to_s
  end

  def test_dup_returns_an_http_uri_instance
    assert_instance_of HTTP::URI, http_uri.dup
  end

  def test_dup_preserves_all_uri_components
    uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")
    duped = uri.dup

    assert_equal "http", duped.scheme
    assert_equal "user", duped.user
    assert_equal "pass", duped.password
    assert_equal "example.com", duped.host
    assert_equal 8080, duped.port
    assert_equal "/path", duped.path
    assert_equal "q=1", duped.query
    assert_equal "frag", duped.fragment
  end

  def test_dup_preserves_ipv6_host_with_brackets
    duped = ipv6_uri.dup

    assert_equal example_ipv6_address, duped.host
    assert_equal "https://[#{example_ipv6_address}]", duped.to_s
  end

  def test_parse_returns_the_same_object_when_given_an_http_uri
    assert_same http_uri, HTTP::URI.parse(http_uri)
  end

  def test_parse_returns_a_new_http_uri_when_given_a_string
    result = HTTP::URI.parse("http://example.com")

    assert_instance_of HTTP::URI, result
  end

  def test_parse_returns_the_same_object_when_given_a_uri_subclass_instance
    subclass = Class.new(HTTP::URI)
    sub_uri = subclass.new(scheme: "http", host: "example.com")
    # is_a?(self) returns true for subclasses; instance_of? does not
    assert_same sub_uri, HTTP::URI.parse(sub_uri)
  end

  def test_parse_raises_invalid_error_for_nil
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse(nil)
    end
    assert_equal "invalid URI: nil", err.message
  end

  def test_parse_raises_invalid_error_for_malformed_uri
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse(":")
    end
    assert_equal 'invalid URI: ":"', err.message
  end

  def test_form_encode_sorts_key_value_pairs_when_sort_is_true
    unsorted = HTTP::URI.form_encode([[:z, 1], [:a, 2]])
    sorted   = HTTP::URI.form_encode([[:z, 1], [:a, 2]], sort: true)

    assert_equal "z=1&a=2", unsorted
    assert_equal "a=2&z=1", sorted
  end

  def test_form_encode_encodes_newlines_as_percent_0a
    assert_equal "text=hello%0Aworld", HTTP::URI.form_encode({ text: "hello\nworld" })
  end

  def test_form_encode_sorts_by_string_representation_of_keys
    result = HTTP::URI.form_encode([[2, "b"], [10, "a"]], sort: true)

    assert_equal "10=a&2=b", result
  end

  def test_percent_encode_returns_nil_when_given_nil
    assert_nil HTTP::URI.send(:percent_encode, nil)
  end

  def test_percent_encode_returns_the_same_string_when_no_encoding_is_needed
    assert_equal "hello", HTTP::URI.send(:percent_encode, "hello")
  end

  def test_percent_encode_encodes_non_ascii_characters_as_percent_encoded_utf8_bytes
    assert_equal "h%C3%A9llo", HTTP::URI.send(:percent_encode, "héllo")
  end

  def test_percent_encode_encodes_multi_byte_characters_into_multiple_percent_encoded_sequences
    # U+1F600 (grinning face) is 4 bytes in UTF-8: F0 9F 98 80
    result = HTTP::URI.send(:percent_encode, "\u{1F600}")

    assert_equal "%F0%9F%98%80", result
  end

  def test_percent_encode_encodes_spaces_as_percent_20
    assert_equal "hello%20world", HTTP::URI.send(:percent_encode, "hello world")
  end

  def test_percent_encode_does_not_encode_printable_ascii_characters
    printable = (0x21..0x7E).map(&:chr).join

    assert_equal printable, HTTP::URI.send(:percent_encode, printable)
  end

  def test_percent_encode_uses_uppercase_hex_digits
    result = HTTP::URI.send(:percent_encode, "\xFF".b.encode(Encoding::UTF_8, Encoding::ISO_8859_1))

    assert_equal "%C3%BF", result
  end

  def remove_dot_segments(path)
    HTTP::URI.send(:remove_dot_segments, path)
  end

  def test_remove_dot_segments_resolves_parent_directory_references
    assert_equal "/a/c", remove_dot_segments("/a/b/../c")
  end

  def test_remove_dot_segments_removes_current_directory_references
    assert_equal "/a/b/c", remove_dot_segments("/a/./b/c")
  end

  def test_remove_dot_segments_resolves_multiple_parent_references
    assert_equal "/c", remove_dot_segments("/a/b/../../c")
  end

  def test_remove_dot_segments_clamps_parent_references_above_root
    assert_equal "/a", remove_dot_segments("/../a")
  end

  def test_remove_dot_segments_preserves_paths_without_dot_segments
    assert_equal "/a/b/c", remove_dot_segments("/a/b/c")
  end

  def test_remove_dot_segments_preserves_trailing_slash_after_parent_reference
    assert_equal "/a/", remove_dot_segments("/a/b/..")
  end

  def test_remove_dot_segments_resolves_current_directory_at_end_of_path
    assert_equal "/a/b/", remove_dot_segments("/a/b/.")
  end

  def test_remove_dot_segments_handles_standalone_dot
    assert_equal "", remove_dot_segments(".")
  end

  def test_remove_dot_segments_handles_standalone_dot_dot
    assert_equal "", remove_dot_segments("..")
  end

  def test_remove_dot_segments_handles_leading_dot_slash_prefix
    assert_equal "a", remove_dot_segments("./a")
  end

  def test_remove_dot_segments_handles_leading_dot_dot_slash_prefix
    assert_equal "a", remove_dot_segments("../a")
  end

  def test_remove_dot_segments_handles_empty_path
    assert_equal "", remove_dot_segments("")
  end

  def test_remove_dot_segments_pops_empty_segment_when_dot_dot_follows_double_slash
    assert_equal "/", remove_dot_segments("//..")
  end

  def test_normalizer_normalizes_an_empty_path_to_slash
    result = HTTP::URI::NORMALIZER.call("http://example.com")

    assert_equal "/", result.path
  end

  def test_normalizer_preserves_non_empty_paths
    result = HTTP::URI::NORMALIZER.call("http://example.com/foo/bar")

    assert_equal "/foo/bar", result.path
  end

  def test_normalizer_removes_dot_segments_from_paths
    result = HTTP::URI::NORMALIZER.call("http://example.com/a/b/../c")

    assert_equal "/a/c", result.path
  end

  def test_normalizer_percent_encodes_non_ascii_characters_in_paths
    result = HTTP::URI::NORMALIZER.call("http://example.com/p\u00E4th")

    assert_includes result.path, "%"
  end

  def test_normalizer_percent_encodes_non_ascii_characters_in_query_strings
    result = HTTP::URI::NORMALIZER.call("http://example.com/?q=v\u00E4lue")

    assert_includes result.query, "%"
  end

  def test_normalizer_returns_an_http_uri_instance
    assert_instance_of HTTP::URI, HTTP::URI::NORMALIZER.call("http://example.com/path")
  end

  def test_normalizer_lowercases_the_scheme
    result = HTTP::URI::NORMALIZER.call("HTTP://example.com")

    assert_equal "http", result.scheme
  end

  def test_normalizer_lowercases_the_host
    result = HTTP::URI::NORMALIZER.call("http://EXAMPLE.COM")

    assert_equal "example.com", result.host
  end

  def test_normalizer_omits_default_http_port
    result = HTTP::URI::NORMALIZER.call("http://example.com:80/path")

    assert_equal "http://example.com/path", result.to_s
  end

  def test_normalizer_omits_default_https_port
    result = HTTP::URI::NORMALIZER.call("https://example.com:443/path")

    assert_equal "https://example.com/path", result.to_s
  end

  def test_normalizer_preserves_non_default_port
    result = HTTP::URI::NORMALIZER.call("http://example.com:8080/path")

    assert_equal "http://example.com:8080/path", result.to_s
  end

  def test_normalizer_preserves_ipv6_host
    result = HTTP::URI::NORMALIZER.call("http://[::1]:8080/path")

    assert_equal "http://[::1]:8080/path", result.to_s
  end

  def test_normalizer_preserves_user_info
    result = HTTP::URI::NORMALIZER.call("http://user:pass@example.com/path")

    assert_equal "user", result.user
    assert_equal "pass", result.password
  end

  def test_normalizer_preserves_fragment
    result = HTTP::URI::NORMALIZER.call("http://example.com/path#frag")

    assert_equal "frag", result.fragment
  end

  def test_equality_returns_false_when_compared_to_a_non_uri_object
    refute_equal "http://example.com", http_uri
  end

  def test_equality_returns_true_for_uris_that_normalize_to_the_same_form
    uri1 = HTTP::URI.parse("HTTP://EXAMPLE.COM")
    uri2 = HTTP::URI.parse("http://example.com")

    assert_equal uri1, uri2
  end

  def test_equality_returns_false_for_uris_that_normalize_differently
    uri1 = HTTP::URI.parse("http://example.com/a")
    uri2 = HTTP::URI.parse("http://example.com/b")

    refute_equal uri1, uri2
  end

  def test_equality_returns_true_when_compared_to_a_uri_subclass_instance
    subclass = Class.new(HTTP::URI)
    sub_uri = subclass.new(scheme: "http", host: "example.com")

    assert_equal http_uri, sub_uri
  end

  def test_eql_returns_false_for_uris_with_different_string_representations
    uri1 = HTTP::URI.parse("http://example.com")
    uri2 = HTTP::URI.parse("http://example.com/")

    refute uri1.eql?(uri2)
  end

  def test_eql_returns_true_for_a_uri_subclass_instance_with_same_string
    subclass = Class.new(HTTP::URI)
    sub_uri = subclass.new(scheme: "http", host: "example.com")

    assert http_uri.eql?(sub_uri)
  end

  def test_hash_returns_the_same_value_on_repeated_calls
    uri = HTTP::URI.parse("http://example.com")
    first  = uri.hash
    second = uri.hash

    assert_equal first, second
  end

  def test_hash_returns_a_composite_hash_of_class_and_string_representation
    uri = HTTP::URI.parse("http://example.com")

    assert_equal [HTTP::URI, uri.to_s].hash, uri.hash
  end

  def test_port_returns_the_explicit_port_when_one_is_set
    uri = HTTP::URI.parse("http://example.com:8080")

    assert_equal 8080, uri.port
  end

  def test_origin_returns_scheme_and_host_for_http_uris
    assert_equal "http://example.com", http_uri.origin
  end

  def test_origin_returns_scheme_and_host_for_https_uris
    assert_equal "https://example.com", https_uri.origin
  end

  def test_origin_includes_non_default_port
    uri = HTTP::URI.parse("http://example.com:8080")

    assert_equal "http://example.com:8080", uri.origin
  end

  def test_origin_omits_default_http_port
    uri = HTTP::URI.parse("http://example.com:80")

    assert_equal "http://example.com", uri.origin
  end

  def test_origin_omits_default_https_port
    uri = HTTP::URI.parse("https://example.com:443")

    assert_equal "https://example.com", uri.origin
  end

  def test_origin_normalizes_scheme_to_lowercase
    uri = HTTP::URI.parse("HTTP://example.com")

    assert_equal "http://example.com", uri.origin
  end

  def test_origin_normalizes_host_to_lowercase
    uri = HTTP::URI.parse("http://EXAMPLE.COM")

    assert_equal "http://example.com", uri.origin
  end

  def test_origin_preserves_ipv6_brackets
    assert_equal "https://[2606:2800:220:1:248:1893:25c8:1946]", ipv6_uri.origin
  end

  def test_origin_excludes_user_info
    uri = HTTP::URI.parse("http://user:pass@example.com")

    assert_equal "http://example.com", uri.origin
  end

  def test_origin_handles_uri_with_no_scheme
    uri = HTTP::URI.new(host: "example.com")

    assert_equal "://example.com", uri.origin
  end

  def test_origin_handles_uri_with_no_host
    uri = HTTP::URI.new(path: "/foo")

    assert_equal "://", uri.origin
  end

  def test_request_uri_returns_path_for_a_simple_uri
    uri = HTTP::URI.parse("http://example.com/path")

    assert_equal "/path", uri.request_uri
  end

  def test_request_uri_returns_path_and_query
    uri = HTTP::URI.parse("http://example.com/path?q=1")

    assert_equal "/path?q=1", uri.request_uri
  end

  def test_request_uri_returns_slash_for_empty_path
    assert_equal "/", http_uri.request_uri
  end

  def test_request_uri_returns_slash_with_query_for_empty_path
    uri = HTTP::URI.parse("http://example.com?q=1")

    assert_equal "/?q=1", uri.request_uri
  end

  def test_request_uri_preserves_trailing_question_mark_with_empty_query
    uri = HTTP::URI.parse("http://example.com/path?")

    assert_equal "/path?", uri.request_uri
  end

  def test_omit_returns_an_http_uri_instance
    full_uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")

    assert_instance_of HTTP::URI, full_uri.omit(:fragment)
  end

  def test_omit_removes_the_fragment_component
    full_uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")

    assert_nil full_uri.omit(:fragment).fragment
  end

  def test_omit_removes_multiple_components
    full_uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")
    result = full_uri.omit(:query, :fragment)

    assert_nil result.query
    assert_nil result.fragment
  end

  def test_omit_preserves_all_other_components_when_omitting_fragment
    full_uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")
    result = full_uri.omit(:fragment)

    assert_equal "http", result.scheme
    assert_equal "user", result.user
    assert_equal "pass", result.password
    assert_equal "example.com", result.host
    assert_equal 8080, result.port
    assert_equal "/path", result.path
    assert_equal "q=1", result.query
  end

  def test_omit_does_not_add_default_port_when_omitting_components
    uri = HTTP::URI.parse("http://example.com/path#frag")

    assert_equal "http://example.com/path", uri.omit(:fragment).to_s
  end

  def test_omit_preserves_ipv6_host_when_omitting_components
    uri = HTTP::URI.parse("https://[::1]:8080/path#frag")

    assert_equal "https://[::1]:8080/path", uri.omit(:fragment).to_s
  end

  def test_omit_returns_unchanged_uri_when_no_components_given
    full_uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")

    assert_equal full_uri.to_s, full_uri.omit.to_s
  end

  def test_join_resolves_a_relative_path
    result = HTTP::URI.parse("http://example.com/foo/").join("bar")

    assert_equal "http://example.com/foo/bar", result.to_s
  end

  def test_join_resolves_an_absolute_path
    result = HTTP::URI.parse("http://example.com/foo").join("/bar")

    assert_equal "http://example.com/bar", result.to_s
  end

  def test_join_resolves_a_full_uri
    result = HTTP::URI.parse("http://example.com/foo").join("http://other.com/bar")

    assert_equal "http://other.com/bar", result.to_s
  end

  def test_join_returns_an_http_uri_instance
    result = HTTP::URI.parse("http://example.com/foo/").join("bar")

    assert_instance_of HTTP::URI, result
  end

  def test_join_accepts_an_http_uri_as_argument
    other = HTTP::URI.parse("http://other.com/bar")
    result = HTTP::URI.parse("http://example.com/foo").join(other)

    assert_equal "http://other.com/bar", result.to_s
  end

  def test_join_percent_encodes_non_ascii_characters_in_the_base_uri
    result = HTTP::URI.parse("http://example.com/K\u00F6nig/").join("bar")

    assert_equal "http://example.com/K%C3%B6nig/bar", result.to_s
  end

  def test_join_percent_encodes_non_ascii_characters_in_the_other_uri
    result = HTTP::URI.parse("http://example.com/").join("/K\u00F6nig")

    assert_equal "http://example.com/K%C3%B6nig", result.to_s
  end

  def test_http_predicate_returns_false_for_non_http_https_schemes
    uri = HTTP::URI.parse("ftp://example.com")

    refute_predicate uri, :http?
  end

  def test_https_predicate_returns_true_for_https_uris
    assert_predicate https_uri, :https?
  end

  def test_https_predicate_returns_false_for_http_uris
    refute_predicate http_uri, :https?
  end

  def test_https_predicate_returns_false_for_non_http_https_schemes
    uri = HTTP::URI.parse("ftp://example.com")

    refute_predicate uri, :https?
  end

  def test_to_s_returns_the_string_representation
    assert_equal "http://example.com", http_uri.to_s
  end

  def test_to_str_is_aliased_to_to_s
    assert_equal http_uri.to_s, http_uri.to_str
  end

  def test_inspect_includes_the_class_name
    assert_includes http_uri.inspect, "HTTP::URI"
  end

  def test_inspect_includes_the_uri_string
    assert_includes http_uri.inspect, "URI:http://example.com"
  end

  def test_inspect_formats_the_object_id_correctly_with_shift
    expected_hex = format("%014x", http_uri.object_id << 1)

    assert_includes http_uri.inspect, expected_hex
  end

  def test_initialize_accepts_keyword_arguments
    uri = HTTP::URI.new(scheme: "http", host: "example.com")

    assert_equal "http", uri.scheme
    assert_equal "example.com", uri.host
  end

  def test_initialize_raises_argument_error_for_an_addressable_uri
    addr_uri = Addressable::URI.parse("http://example.com")

    assert_raises(ArgumentError) { HTTP::URI.new(addr_uri) }
  end

  def test_initialize_raises_argument_error_for_a_positional_argument
    assert_raises(ArgumentError) { HTTP::URI.new(42) }
  end

  def test_initialize_works_with_no_arguments
    uri = HTTP::URI.new

    assert_instance_of HTTP::URI, uri
  end

  def test_deconstruct_keys_returns_all_keys_when_given_nil
    full_uri = HTTP::URI.parse("http://user:pass@example.com:8080/path?q=1#frag")
    result = full_uri.deconstruct_keys(nil)

    assert_equal "http", result[:scheme]
    assert_equal "example.com", result[:host]
    assert_equal 8080, result[:port]
    assert_equal "/path", result[:path]
    assert_equal "q=1", result[:query]
    assert_equal "frag", result[:fragment]
    assert_equal "user", result[:user]
    assert_equal "pass", result[:password]
  end

  def test_deconstruct_keys_returns_only_requested_keys
    result = http_uri.deconstruct_keys(%i[scheme host])

    assert_equal({ scheme: "http", host: "example.com" }, result)
  end

  def test_deconstruct_keys_excludes_unrequested_keys
    result = http_uri.deconstruct_keys([:host])

    refute_includes result.keys, :scheme
    refute_includes result.keys, :port
  end

  def test_deconstruct_keys_returns_empty_hash_for_empty_keys
    assert_equal({}, http_uri.deconstruct_keys([]))
  end

  def test_deconstruct_keys_returns_correct_port_for_https_uris
    assert_equal 443, https_uri.deconstruct_keys([:port])[:port]
  end

  def test_deconstruct_keys_supports_pattern_matching_with_case_in
    matched = case http_uri
              in { scheme: "http", host: /example/ }
                true
              else
                false
              end

    assert matched
  end

  def test_process_ipv6_brackets_handles_ipv4_addresses
    uri = HTTP::URI.parse("http://example.com")
    uri.host = "192.168.1.1"

    assert_equal "192.168.1.1", uri.host
  end

  def test_process_ipv6_brackets_handles_regular_hostnames
    uri = HTTP::URI.parse("http://example.com")
    uri.host = "example.org"

    assert_equal "example.org", uri.host
  end

  def test_process_ipv6_brackets_handles_invalid_ip_address_strings_gracefully
    uri = HTTP::URI.parse("http://example.com")
    uri.host = "not-an-ip"

    assert_equal "not-an-ip", uri.host
  end

  def test_parse_raises_invalid_error_with_message_containing_inspect_for_non_stringable_objects
    obj = Object.new
    def obj.to_str
      raise NoMethodError
    end

    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse(obj)
    end
    assert_kind_of HTTP::URI::InvalidError, err
    assert_includes err.message, "invalid URI: "
    assert_includes err.message, obj.inspect
    refute_equal obj.inspect, err.message
  end

  def test_parse_raises_invalid_error_for_an_object_whose_to_str_raises_type_error
    obj = Object.new
    def obj.to_str
      raise TypeError
    end

    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse(obj)
    end
    assert_kind_of HTTP::URI::InvalidError, err
    assert_includes err.message, obj.inspect
    refute_equal obj.inspect, err.message
  end

  def test_parse_via_parse_components_parses_non_ascii_uri_with_all_components
    uri = HTTP::URI.parse("http://us\u00E9r:p\u00E4ss@ex\u00E4mple.com:9090/p\u00E4th?q=v\u00E4l#fr\u00E4g")

    assert_equal "us\u00E9r", uri.user
    assert_equal "p\u00E4ss", uri.password
    assert_equal 9090, uri.port
    assert_includes String(uri), "fr\u00E4g"
  end

  def test_parse_via_parse_components_parses_an_ascii_uri_via_stdlib
    uri = HTTP::URI.parse("http://example.com/path?q=1#frag")

    assert_equal "http", uri.scheme
    assert_equal "example.com", uri.host
    assert_equal "/path", uri.path
    assert_equal "q=1", uri.query
    assert_equal "frag", uri.fragment
  end

  def test_parse_via_parse_components_strips_default_port_when_parsing_ascii_uri
    uri = HTTP::URI.parse("http://example.com:80/path")

    assert_equal "http://example.com/path", uri.to_s
  end

  def test_parse_via_parse_components_falls_back_to_addressable_when_stdlib_fails
    uri = HTTP::URI.parse("http://example.com/path with spaces")

    assert_equal "http", uri.scheme
    assert_equal "example.com", uri.host
  end

  def test_parse_via_parse_components_raises_invalid_error_for_invalid_non_ascii_uri
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse("ht\u00FCtp://[invalid")
    end
    assert_kind_of HTTP::URI::InvalidError, err
    assert_includes err.message, "invalid URI:"
    assert_includes err.message, "invalid"
  end

  def test_parse_via_parse_components_raises_invalid_error_for_stdlib_invalid_uri
    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse("http://exam ple.com")
    end
    assert_kind_of HTTP::URI::InvalidError, err
    assert_includes err.message, "invalid URI:"
    assert_includes err.message, "exam ple.com"
  end

  def test_parse_via_parse_components_parses_non_ascii_uri_preserving_fragment
    uri = HTTP::URI.parse("http://ex\u00E4mple.com/path#sec\u00F6tion")

    assert_equal "sec\u00F6tion", uri.fragment
  end

  def test_parse_via_parse_components_parses_non_ascii_uri_preserving_user_without_password
    uri = HTTP::URI.parse("http://\u00FCser@ex\u00E4mple.com/")

    assert_equal "\u00FCser", uri.user
    assert_nil uri.password
  end

  def test_parse_via_parse_components_routes_ascii_control_characters_to_addressable
    uri = HTTP::URI.parse("http://example.com/?\x00\x7F\n")

    assert_equal "\x00\x7F\n", uri.query
  end

  def test_to_s_serializes_scheme_only_uri
    uri = HTTP::URI.new(scheme: "http")

    assert_equal "http:", uri.to_s
  end

  def test_to_s_omits_scheme_prefix_when_scheme_is_nil
    uri = HTTP::URI.new(host: "example.com", path: "/path")

    assert_equal "//example.com/path", uri.to_s
  end

  def test_to_s_serializes_uri_with_user_and_password
    uri = HTTP::URI.new(scheme: "http", user: "admin", password: "secret", host: "example.com")

    assert_equal "http://admin:secret@example.com", uri.to_s
  end

  def test_to_s_serializes_uri_with_user_but_no_password
    uri = HTTP::URI.new(scheme: "http", user: "admin", host: "example.com")

    assert_equal "http://admin@example.com", uri.to_s
  end

  def test_to_s_serializes_uri_with_explicit_port
    uri = HTTP::URI.new(scheme: "http", host: "example.com", port: 8080)

    assert_equal "http://example.com:8080", uri.to_s
  end

  def test_to_s_serializes_uri_with_query
    uri = HTTP::URI.new(scheme: "http", host: "example.com", path: "/path", query: "a=1")

    assert_equal "http://example.com/path?a=1", uri.to_s
  end

  def test_to_s_serializes_uri_with_fragment
    uri = HTTP::URI.new(scheme: "http", host: "example.com", path: "/path", fragment: "sec")

    assert_equal "http://example.com/path#sec", uri.to_s
  end

  def test_to_s_serializes_uri_with_all_components
    uri = HTTP::URI.new(
      scheme: "http", user: "u", password: "p", host: "h.com",
      port: 9090, path: "/x", query: "q=1", fragment: "f"
    )

    assert_equal "http://u:p@h.com:9090/x?q=1#f", uri.to_s
  end

  def test_to_s_serializes_path_only_uri
    uri = HTTP::URI.new(path: "/just/a/path")

    assert_equal "/just/a/path", uri.to_s
  end

  def test_to_s_serializes_uri_without_host_omitting_double_slash
    uri = HTTP::URI.new(scheme: "mailto", path: "user@example.com")

    assert_equal "mailto:user@example.com", uri.to_s
  end

  def test_to_s_serializes_query_only_uri_without_host
    uri = HTTP::URI.new(path: "/p", query: "q=1")

    assert_equal "/p?q=1", uri.to_s
  end

  def test_to_s_serializes_fragment_only_uri_without_host
    uri = HTTP::URI.new(path: "/p", fragment: "f")

    assert_equal "/p#f", uri.to_s
  end

  def test_normalize_lowercases_the_scheme
    uri = HTTP::URI.new(scheme: "HTTP", host: "example.com")

    assert_equal "http", uri.normalize.scheme
  end

  def test_normalize_lowercases_the_host
    uri = HTTP::URI.new(scheme: "http", host: "EXAMPLE.COM")

    assert_equal "example.com", uri.normalize.host
  end

  def test_normalize_strips_default_port
    uri = HTTP::URI.new(scheme: "http", host: "example.com", port: 80, path: "/path")

    assert_nil uri.normalize.instance_variable_get(:@port)
  end

  def test_normalize_preserves_non_default_port
    uri = HTTP::URI.parse("http://example.com:8080/path")
    normalized = uri.normalize

    assert_equal 8080, normalized.instance_variable_get(:@port)
  end

  def test_normalize_normalizes_empty_path_to_slash_when_host_is_present
    uri = HTTP::URI.new(scheme: "http", host: "example.com")

    assert_equal "/", uri.normalize.path
  end

  def test_normalize_preserves_non_empty_path
    uri = HTTP::URI.parse("http://example.com/foo")

    assert_equal "/foo", uri.normalize.path
  end

  def test_normalize_preserves_user
    uri = HTTP::URI.parse("http://myuser@example.com/")

    assert_equal "myuser", uri.normalize.user
  end

  def test_normalize_preserves_password
    uri = HTTP::URI.parse("http://u:mypass@example.com/")

    assert_equal "mypass", uri.normalize.password
  end

  def test_normalize_preserves_query
    uri = HTTP::URI.parse("http://example.com/?q=val")

    assert_equal "q=val", uri.normalize.query
  end

  def test_normalize_preserves_fragment
    uri = HTTP::URI.parse("http://example.com/#frag")

    assert_equal "frag", uri.normalize.fragment
  end

  def test_normalize_handles_nil_scheme
    uri = HTTP::URI.new(host: "example.com")

    assert_nil uri.normalize.scheme
  end

  def test_normalize_handles_nil_host
    uri = HTTP::URI.new(scheme: "http", path: "/path")

    assert_nil uri.normalize.host
  end

  def test_normalize_does_not_normalize_empty_path_to_slash_without_host
    uri = HTTP::URI.new(scheme: "http")

    assert_equal "", uri.normalize.path
  end

  def test_normalize_returns_a_complete_normalized_string
    uri = HTTP::URI.parse("HTTP://USER:PASS@EXAMPLE.COM:8080/path?q=1#frag")
    normalized = uri.normalize

    assert_equal "http://USER:PASS@example.com:8080/path?q=1#frag", String(normalized)
  end

  def test_normalized_host_lowercases_the_host
    uri = HTTP::URI.new(host: "EXAMPLE.COM")

    assert_equal "example.com", uri.normalized_host
  end

  def test_normalized_host_decodes_percent_encoded_characters
    uri = HTTP::URI.new(host: "%65%78ample.com")

    assert_equal "example.com", uri.normalized_host
  end

  def test_normalized_host_decodes_multiple_percent_encoded_characters
    uri = HTTP::URI.new(host: "%65%78%61mple.com")

    assert_equal "example.com", uri.normalized_host
  end

  def test_normalized_host_strips_trailing_dot_from_domain
    uri = HTTP::URI.new(host: "example.com.")

    assert_equal "example.com", uri.normalized_host
  end

  def test_normalized_host_returns_nil_for_nil_host
    uri = HTTP::URI.new

    assert_nil uri.normalized_host
  end

  def test_normalized_host_encodes_idn_non_ascii_hostnames_to_ascii
    uri = HTTP::URI.new(host: "ex\u00E4mple.com")

    assert_equal "xn--exmple-cua.com", uri.normalized_host
  end

  def test_normalized_host_does_not_idn_encode_already_ascii_hostnames
    uri = HTTP::URI.new(host: "example.com")

    assert_equal "example.com", uri.normalized_host
  end

  def test_host_assignment_applies_normalize_host_to_the_new_host
    uri = HTTP::URI.parse("http://example.com")
    uri.host = "NEW-HOST.COM."

    assert_equal "new-host.com", uri.normalized_host
  end

  def test_default_port_returns_default_port_for_uppercase_scheme
    uri = HTTP::URI.new(scheme: "HTTP")

    assert_equal 80, uri.default_port
  end

  def test_default_port_returns_nil_for_unknown_scheme
    uri = HTTP::URI.new(scheme: "ftp")

    assert_nil uri.default_port
  end

  def test_default_port_returns_default_port_for_ws_scheme
    uri = HTTP::URI.new(scheme: "ws")

    assert_equal 80, uri.default_port
  end

  def test_default_port_returns_default_port_for_wss_scheme
    uri = HTTP::URI.new(scheme: "wss")

    assert_equal 443, uri.default_port
  end

  def test_origin_lowercases_an_uppercase_scheme
    uri = HTTP::URI.new(scheme: "HTTP", host: "example.com")

    assert_equal "http://example.com", uri.origin
  end

  def test_process_ipv6_brackets_returns_nil_host_as_nil
    uri = HTTP::URI.new(host: nil)

    assert_nil uri.host
  end

  def test_process_ipv6_brackets_does_not_strip_brackets_from_ipv4_addresses
    uri = HTTP::URI.new(host: "192.168.1.1")

    assert_equal "192.168.1.1", uri.host
    assert_equal "192.168.1.1", uri.instance_variable_get(:@raw_host)
  end

  def test_process_ipv6_brackets_does_not_bracket_ipv4_addresses_in_host_assignment
    uri = HTTP::URI.parse("http://example.com")
    uri.host = "10.0.0.1"

    assert_equal "http://10.0.0.1", uri.to_s
  end

  def test_parse_error_messages_uses_inspect_in_the_rescue
    obj = Object.new
    def obj.to_s
      "CUSTOM_TO_S"
    end

    def obj.to_str
      raise NoMethodError
    end

    err = assert_raises(HTTP::URI::InvalidError) do
      HTTP::URI.parse(obj)
    end

    refute_includes err.message, "CUSTOM_TO_S"
  end

  def test_dup_does_not_copy_memoized_hash_ivar
    uri = HTTP::URI.parse("http://example.com")
    uri.hash # memoize @hash

    duped = uri.dup

    refute duped.instance_variable_defined?(:@hash)
  end

  def test_normalize_strips_port_443_for_https
    uri = HTTP::URI.new(scheme: "https", host: "example.com", port: 443, path: "/")

    assert_nil uri.normalize.instance_variable_get(:@port)
  end

  def test_normalize_does_not_strip_non_default_port
    uri = HTTP::URI.new(scheme: "http", host: "example.com", port: 9090, path: "/")

    assert_equal 9090, uri.normalize.instance_variable_get(:@port)
  end
end
