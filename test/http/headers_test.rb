# frozen_string_literal: true

require "test_helper"

class HTTPHeadersTest < Minitest::Test
  cover "HTTP::Headers*"

  def headers
    @headers ||= HTTP::Headers.new
  end

  def test_is_enumerable
    assert_kind_of Enumerable, headers
  end

  # -- #set -------------------------------------------------------------------

  def test_set_sets_header_value
    headers.set "Accept", "application/json"

    assert_equal "application/json", headers["Accept"]
  end

  def test_set_allows_retrieval_via_normalized_header_name
    headers.set :content_type, "application/json"

    assert_equal "application/json", headers["Content-Type"]
  end

  def test_set_overwrites_previous_value
    headers.set :set_cookie, "hoo=ray"
    headers.set :set_cookie, "woo=hoo"

    assert_equal "woo=hoo", headers["Set-Cookie"]
  end

  def test_set_allows_set_multiple_values
    headers.set :set_cookie, "hoo=ray"
    headers.set :set_cookie, %w[hoo=ray woo=hoo]

    assert_equal %w[hoo=ray woo=hoo], headers["Set-Cookie"]
  end

  def test_set_fails_with_empty_header_name
    assert_raises(HTTP::HeaderError) { headers.set "", "foo bar" }
  end

  ["foo bar", "foo bar: ok\nfoo", "evil-header: evil-value\nfoo"].each do |name|
    define_method :"test_set_fails_with_invalid_header_name_#{name.inspect}" do
      assert_raises(HTTP::HeaderError) { headers.set name, "baz" }
    end
  end

  def test_set_fails_with_invalid_header_value
    assert_raises(HTTP::HeaderError) { headers.set "foo", "bar\nEvil-Header: evil-value" }
  end

  # -- #[]= ------------------------------------------------------------------

  def test_bracket_assign_sets_header_value
    headers["Accept"] = "application/json"

    assert_equal "application/json", headers["Accept"]
  end

  def test_bracket_assign_allows_retrieval_via_normalized_header_name
    headers[:content_type] = "application/json"

    assert_equal "application/json", headers["Content-Type"]
  end

  def test_bracket_assign_overwrites_previous_value
    headers[:set_cookie] = "hoo=ray"
    headers[:set_cookie] = "woo=hoo"

    assert_equal "woo=hoo", headers["Set-Cookie"]
  end

  def test_bracket_assign_allows_set_multiple_values
    headers[:set_cookie] = "hoo=ray"
    headers[:set_cookie] = %w[hoo=ray woo=hoo]

    assert_equal %w[hoo=ray woo=hoo], headers["Set-Cookie"]
  end

  # -- #delete ----------------------------------------------------------------

  def test_delete_removes_given_header
    headers.set "Content-Type", "application/json"
    headers.delete "Content-Type"

    assert_nil headers["Content-Type"]
  end

  def test_delete_removes_header_that_matches_normalized_version_of_specified_name
    headers.set "Content-Type", "application/json"
    headers.delete :content_type

    assert_nil headers["Content-Type"]
  end

  def test_delete_calls_to_s_on_non_string_name_argument
    headers.set "Content-Type", "application/json"
    name = fake(to_s: "Content-Type")
    headers.delete name

    assert_nil headers["Content-Type"]
  end

  def test_delete_fails_with_empty_header_name
    headers.set "Content-Type", "application/json"

    assert_raises(HTTP::HeaderError) { headers.delete "" }
  end

  ["foo bar", "foo bar: ok\nfoo"].each do |name|
    define_method :"test_delete_fails_with_invalid_header_name_#{name.inspect}" do
      headers.set "Content-Type", "application/json"

      assert_raises(HTTP::HeaderError) { headers.delete name }
    end
  end

  # -- #add -------------------------------------------------------------------

  def test_add_sets_header_value
    headers.add "Accept", "application/json"

    assert_equal "application/json", headers["Accept"]
  end

  def test_add_allows_retrieval_via_normalized_header_name
    headers.add :content_type, "application/json"

    assert_equal "application/json", headers["Content-Type"]
  end

  def test_add_appends_new_value_if_header_exists
    headers.add "Set-Cookie", "hoo=ray"
    headers.add :set_cookie, "woo=hoo"

    assert_equal %w[hoo=ray woo=hoo], headers["Set-Cookie"]
  end

  def test_add_allows_append_multiple_values
    headers.add :set_cookie, "hoo=ray"
    headers.add :set_cookie, %w[woo=hoo yup=pie]

    assert_equal %w[hoo=ray woo=hoo yup=pie], headers["Set-Cookie"]
  end

  def test_add_fails_with_empty_header_name
    assert_raises(HTTP::HeaderError) { headers.add("", "foobar") }
  end

  ["foo bar", "foo bar: ok\nfoo"].each do |name|
    define_method :"test_add_fails_with_invalid_header_name_#{name.inspect}" do
      assert_raises(HTTP::HeaderError) { headers.add name, "baz" }
    end
  end

  def test_add_fails_with_invalid_header_value
    assert_raises(HTTP::HeaderError) { headers.add "foo", "bar\nEvil-Header: evil-value" }
  end

  def test_add_fails_when_header_name_is_not_a_string_or_symbol
    err = assert_raises(HTTP::HeaderError) { headers.add 2, "foo" }
    assert_includes err.message, "2"
  end

  def test_add_includes_inspect_formatted_name_in_error_for_non_string_symbol
    obj = Object.new
    def obj.to_s = "plain"
    def obj.inspect = "INSPECTED"

    err = assert_raises(HTTP::HeaderError) { headers.add obj, "foo" }
    assert_includes err.message, "INSPECTED"
  end

  def test_add_uses_normalized_name_as_wire_name_for_symbol_keys_in_to_a
    headers.add :content_type, "application/json"

    assert_equal [["Content-Type", "application/json"]], headers.to_a
  end

  def test_add_preserves_original_string_as_wire_name_for_string_keys_in_to_a
    headers.add "auth_key", "secret"

    assert_equal [%w[auth_key secret]], headers.to_a
  end

  def test_add_calls_to_s_on_symbol_name_for_normalization
    headers.add :accept, "text/html"

    assert_equal [["Accept", "text/html"]], headers.to_a
  end

  # -- #get -------------------------------------------------------------------

  def test_get_returns_array_of_associated_values
    headers.set("Content-Type", "application/json")

    assert_equal %w[application/json], headers.get("Content-Type")
  end

  def test_get_normalizes_header_name
    headers.set("Content-Type", "application/json")

    assert_equal %w[application/json], headers.get(:content_type)
  end

  def test_get_when_header_does_not_exist_returns_empty_array
    headers.set("Content-Type", "application/json")

    assert_equal [], headers.get(:accept)
  end

  def test_get_calls_to_s_on_non_string_name_argument
    headers.set("Content-Type", "application/json")
    name = fake(to_s: "Content-Type")

    assert_equal %w[application/json], headers.get(name)
  end

  def test_get_fails_with_empty_header_name
    headers.set("Content-Type", "application/json")

    assert_raises(HTTP::HeaderError) { headers.get("") }
  end

  ["foo bar", "foo bar: ok\nfoo"].each do |name|
    define_method :"test_get_fails_with_invalid_header_name_#{name.inspect}" do
      headers.set("Content-Type", "application/json")

      assert_raises(HTTP::HeaderError) { headers.get name }
    end
  end

  # -- #[] -------------------------------------------------------------------

  def test_bracket_when_header_does_not_exist_returns_nil
    assert_nil headers[:accept]
  end

  def test_bracket_single_value_normalizes_header_name
    headers.set "Content-Type", "application/json"

    refute_nil headers[:content_type]
  end

  def test_bracket_single_value_returns_single_value
    headers.set "Content-Type", "application/json"

    assert_equal "application/json", headers[:content_type]
  end

  def test_bracket_multiple_values_normalizes_header_name
    headers.add :set_cookie, "hoo=ray"
    headers.add :set_cookie, "woo=hoo"

    refute_nil headers[:set_cookie]
  end

  def test_bracket_multiple_values_returns_array_of_associated_values
    headers.add :set_cookie, "hoo=ray"
    headers.add :set_cookie, "woo=hoo"

    assert_equal %w[hoo=ray woo=hoo], headers[:set_cookie]
  end

  def test_bracket_returns_nil_for_missing_header
    headers.set "Content-Type", "text/plain"
    result = headers[:nonexistent]

    assert_nil result
  end

  def test_bracket_returns_string_for_single_value
    headers.set "Content-Type", "text/plain"

    result = headers["Content-Type"]

    assert_instance_of String, result
    assert_equal "text/plain", result
  end

  def test_bracket_returns_array_for_multiple_values
    headers.add :cookie, "a=1"
    headers.add :cookie, "b=2"

    result = headers[:cookie]

    assert_instance_of Array, result
    assert_equal %w[a=1 b=2], result
  end

  # -- #include? --------------------------------------------------------------

  def test_include_tells_whenever_given_headers_is_set_or_not
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_includes headers, "Content-Type"
    assert_includes headers, "Set-Cookie"
    refute_includes headers, "Accept"
  end

  def test_include_normalizes_given_header_name
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_includes headers, :content_type
    assert_includes headers, :set_cookie
    refute_includes headers, :accept
  end

  def test_include_calls_to_s_on_non_string_name_argument
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"
    name = fake(to_s: "Content-Type")

    assert_includes headers, name
  end

  def test_include_finds_headers_added_with_non_canonical_string_keys
    h = HTTP::Headers.new
    h.add("x-custom", "value")

    assert_includes h, "x-custom"
  end

  # -- #to_h ------------------------------------------------------------------

  def test_to_h_returns_a_hash
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_kind_of Hash, headers.to_h
  end

  def test_to_h_returns_hash_with_normalized_keys
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_equal %w[Content-Type Set-Cookie].sort, headers.to_h.keys.sort
  end

  def test_to_h_single_value_provides_value_as_is
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_equal "application/json", headers.to_h["Content-Type"]
  end

  def test_to_h_multiple_values_provides_array_of_values
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_equal %w[hoo=ray woo=hoo], headers.to_h["Set-Cookie"]
  end

  # -- #to_a ------------------------------------------------------------------

  def test_to_a_returns_an_array
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_kind_of Array, headers.to_a
  end

  def test_to_a_returns_array_of_key_value_pairs_with_normalized_keys
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_equal [
      %w[Content-Type application/json],
      %w[Set-Cookie hoo=ray],
      %w[Set-Cookie woo=hoo]
    ], headers.to_a
  end

  def test_to_a_returns_two_element_arrays
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    headers.to_a.each do |pair|
      assert_equal 2, pair.size, "Expected each element to be a [name, value] pair"
    end
  end

  def test_to_a_returns_wire_name_as_first_element
    h = HTTP::Headers.new
    h.add "X_Custom", "val"

    assert_equal [%w[X_Custom val]], h.to_a
  end

  # -- #deconstruct_keys ------------------------------------------------------

  def test_deconstruct_keys_returns_all_keys_as_snake_case_symbols_when_given_nil
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    result = headers.deconstruct_keys(nil)

    assert_equal "application/json", result[:content_type]
    assert_equal %w[hoo=ray woo=hoo], result[:set_cookie]
  end

  def test_deconstruct_keys_converts_header_names_to_snake_case_symbols
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_includes headers.deconstruct_keys(nil).keys, :content_type
    assert_includes headers.deconstruct_keys(nil).keys, :set_cookie
  end

  def test_deconstruct_keys_returns_only_requested_keys
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    result = headers.deconstruct_keys([:content_type])

    assert_equal({ content_type: "application/json" }, result)
  end

  def test_deconstruct_keys_excludes_unrequested_keys
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    refute_includes headers.deconstruct_keys([:content_type]).keys, :set_cookie
  end

  def test_deconstruct_keys_returns_empty_hash_for_empty_keys
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_equal({}, headers.deconstruct_keys([]))
  end

  def test_deconstruct_keys_supports_pattern_matching_with_case_in
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    matched = case headers
              in { content_type: /json/ }
                true
              else
                false
              end

    assert matched
  end

  # -- #inspect ---------------------------------------------------------------

  def test_inspect_returns_a_human_readable_representation
    headers.set :set_cookie, %w[hoo=ray woo=hoo]

    assert_equal "#<HTTP::Headers>", headers.inspect
  end

  # -- #keys ------------------------------------------------------------------

  def test_keys_returns_uniq_keys_only
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_equal 2, headers.keys.size
  end

  def test_keys_normalizes_keys
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "hoo=ray"
    headers.add :set_cookie,   "woo=hoo"

    assert_includes headers.keys, "Content-Type"
    assert_includes headers.keys, "Set-Cookie"
  end

  # -- #each ------------------------------------------------------------------

  def test_each_yields_each_key_value_pair_separately
    headers.add :set_cookie,   "hoo=ray"
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "woo=hoo"

    yielded = headers.map { |pair| pair }

    assert_equal 3, yielded.size
  end

  def test_each_yields_headers_in_the_same_order_they_were_added
    headers.add :set_cookie,   "hoo=ray"
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "woo=hoo"

    yielded = headers.map { |pair| pair }

    assert_equal [
      %w[Set-Cookie hoo=ray],
      %w[Content-Type application/json],
      %w[Set-Cookie woo=hoo]
    ], yielded
  end

  def test_each_yields_header_keys_specified_as_symbols_in_normalized_form
    headers.add :set_cookie,   "hoo=ray"
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "woo=hoo"

    keys = headers.each.map(&:first)

    assert_equal %w[Set-Cookie Content-Type Set-Cookie], keys
  end

  def test_each_yields_headers_specified_as_strings_without_conversion
    headers.add :set_cookie,   "hoo=ray"
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "woo=hoo"
    headers.add "X_kEy", "value"

    keys = headers.each.map(&:first)

    assert_equal %w[Set-Cookie Content-Type Set-Cookie X_kEy], keys
  end

  def test_each_returns_self_instance_if_block_given
    assert_same(headers, headers.each { |*| nil })
  end

  def test_each_returns_enumerator_if_no_block_given
    assert_kind_of Enumerator, headers.each
  end

  def test_each_yields_two_element_arrays
    headers.add :set_cookie,   "hoo=ray"
    headers.add :content_type, "application/json"
    headers.add :set_cookie,   "woo=hoo"

    headers.each do |pair|
      assert_equal 2, pair.size
    end
  end

  # -- .empty? ----------------------------------------------------------------

  def test_empty_initially_is_true
    assert_empty headers
  end

  def test_empty_when_header_exists_is_false
    headers.add :accept, "text/plain"

    refute_empty headers
  end

  def test_empty_when_last_header_was_removed_is_true
    headers.add :accept, "text/plain"
    headers.delete :accept

    assert_empty headers
  end

  # -- #hash ------------------------------------------------------------------

  def test_hash_equals_if_two_headers_equals
    left  = HTTP::Headers.new
    right = HTTP::Headers.new

    left.add :accept, "text/plain"
    right.add :accept, "text/plain"

    assert_equal left.hash, right.hash
  end

  # -- #== -------------------------------------------------------------------

  def test_eq_compares_header_keys_and_values
    left  = HTTP::Headers.new
    right = HTTP::Headers.new

    left.add :accept, "text/plain"
    right.add :accept, "text/plain"

    assert_equal left, right
  end

  def test_eq_allows_comparison_with_array_of_key_value_pairs
    left = HTTP::Headers.new
    left.add :accept, "text/plain"

    assert_equal [%w[Accept text/plain]], left.to_a
  end

  def test_eq_sensitive_to_headers_order
    left  = HTTP::Headers.new
    right = HTTP::Headers.new

    left.add :accept, "text/plain"
    left.add :cookie, "woo=hoo"
    right.add :cookie, "woo=hoo"
    right.add :accept, "text/plain"

    refute_equal left, right
  end

  def test_eq_sensitive_to_header_values_order
    left  = HTTP::Headers.new
    right = HTTP::Headers.new

    left.add :cookie, "hoo=ray"
    left.add :cookie, "woo=hoo"
    right.add :cookie, "woo=hoo"
    right.add :cookie, "hoo=ray"

    refute_equal left, right
  end

  def test_eq_returns_false_when_compared_to_object_without_to_a
    left = HTTP::Headers.new
    left.add :accept, "text/plain"

    refute_equal left, 42
  end

  # -- #dup -------------------------------------------------------------------

  def test_dup_returns_an_http_headers_instance
    headers.set :content_type, "application/json"
    dupped = headers.dup

    assert_kind_of HTTP::Headers, dupped
  end

  def test_dup_is_not_the_same_object
    headers.set :content_type, "application/json"
    dupped = headers.dup

    refute_same headers, dupped
  end

  def test_dup_has_headers_copied
    headers.set :content_type, "application/json"
    dupped = headers.dup

    assert_equal "application/json", dupped[:content_type]
  end

  def test_dup_modifying_copy_modifies_dupped_copy
    headers.set :content_type, "application/json"
    dupped = headers.dup
    dupped.set :content_type, "text/plain"

    assert_equal "text/plain", dupped[:content_type]
  end

  def test_dup_modifying_copy_does_not_affect_original_headers
    headers.set :content_type, "application/json"
    dupped = headers.dup
    dupped.set :content_type, "text/plain"

    assert_equal "application/json", headers[:content_type]
  end

  def test_dup_deep_copies_internal_pile_entries
    headers.set :content_type, "application/json"
    dupped = headers.dup

    original_pile = headers.instance_variable_get(:@pile)
    dupped_pile   = dupped.instance_variable_get(:@pile)

    # The outer arrays should be different objects
    refute_same original_pile, dupped_pile

    # Each inner array should also be a different object
    original_pile.each_with_index do |entry, i|
      refute_same entry, dupped_pile[i]
    end
  end

  # -- validate_value (via #add) ----------------------------------------------

  def test_validate_value_raises_header_error_when_value_contains_newline
    err = assert_raises(HTTP::HeaderError) { headers.add "X-Test", "foo\nbar" }
    assert_includes err.message, "foo"
  end

  def test_validate_value_accepts_values_without_newlines
    headers.add "X-Test", "foobar"

    assert_equal "foobar", headers["X-Test"]
  end

  def test_validate_value_calls_to_s_on_non_string_values
    numeric_value = 42
    headers.add "X-Number", numeric_value

    assert_equal "42", headers["X-Number"]
  end

  def test_validate_value_raises_header_error_when_to_s_result_contains_newline
    evil = fake(to_s: "good\nevil")

    assert_raises(HTTP::HeaderError) { headers.add "X-Evil", evil }
  end

  def test_validate_value_includes_inspected_value_in_error_message
    err = assert_raises(HTTP::HeaderError) { headers.add "Test", "bad\nvalue" }

    assert_includes err.message, '"bad\nvalue"'
  end

  def test_validate_value_raises_header_error_when_value_contains_carriage_return
    assert_raises(HTTP::HeaderError) { headers.add "X-Test", "foo\rbar" }
  end

  def test_validate_value_raises_header_error_when_value_contains_crlf
    assert_raises(HTTP::HeaderError) { headers.add "X-Test", "foo\r\nbar" }
  end

  # -- #merge! ----------------------------------------------------------------

  def test_merge_bang_leaves_headers_not_presented_in_other_as_is
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    headers.merge! accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_equal "example.com", headers[:host]
  end

  def test_merge_bang_overwrites_existing_values
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    headers.merge! accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_equal "plain/text", headers[:accept]
  end

  def test_merge_bang_appends_other_headers_not_presented_in_base
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    headers.merge! accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_equal %w[hoo=ray woo=hoo], headers[:cookie]
  end

  def test_merge_bang_accepts_an_http_headers_instance
    other = HTTP::Headers.new
    other.set :accept, "text/xml"

    h = HTTP::Headers.new
    h.set :accept, "application/json"
    h.merge!(other)

    assert_equal "text/xml", h[:accept]
  end

  def test_merge_bang_uses_set_so_existing_values_are_replaced
    h = HTTP::Headers.new
    h.add :accept, "text/html"
    h.add :accept, "text/plain"
    h[:accept] = "application/json"

    assert_equal "application/json", h[:accept]
  end

  # -- #merge -----------------------------------------------------------------

  def test_merge_returns_an_http_headers_instance
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    merged = headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_kind_of HTTP::Headers, merged
  end

  def test_merge_is_not_the_same_object
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    merged = headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    refute_same headers, merged
  end

  def test_merge_does_not_affect_original_headers
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    merged = headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    refute_equal merged.to_h, headers.to_h
  end

  def test_merge_leaves_headers_not_presented_in_other_as_is
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    merged = headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_equal "example.com", merged[:host]
  end

  def test_merge_overwrites_existing_values
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    merged = headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_equal "plain/text", merged[:accept]
  end

  def test_merge_appends_other_headers_not_presented_in_base
    headers.set :host, "example.com"
    headers.set :accept, "application/json"
    merged = headers.merge accept: "plain/text", cookie: %w[hoo=ray woo=hoo]

    assert_equal %w[hoo=ray woo=hoo], merged[:cookie]
  end

  # -- .coerce ----------------------------------------------------------------

  def test_coerce_accepts_any_object_that_respond_to_to_hash
    hashie = fake(to_hash: { "accept" => "json" })

    assert_equal "json", HTTP::Headers.coerce(hashie)["accept"]
  end

  def test_coerce_accepts_any_object_that_respond_to_to_h
    hashie = fake(to_h: { "accept" => "json" })

    assert_equal "json", HTTP::Headers.coerce(hashie)["accept"]
  end

  def test_coerce_accepts_any_object_that_respond_to_to_a
    hashie = fake(to_a: [%w[accept json]])

    assert_equal "json", HTTP::Headers.coerce(hashie)["accept"]
  end

  def test_coerce_fails_if_given_object_cannot_be_coerced
    obj = Object.new
    def obj.respond_to?(*); end
    def obj.inspect = "INSPECTED"
    def obj.to_s = "plain"

    err = assert_raises(HTTP::Error) { HTTP::Headers.coerce obj }
    assert_includes err.message, "INSPECTED"
  end

  def test_coerce_with_duplicate_header_keys_adds_all_headers
    hdrs = { "Set-Cookie" => "hoo=ray", "set_cookie" => "woo=hoo", :set_cookie => "ta=da" }
    expected = [%w[Set-Cookie hoo=ray], %w[set_cookie woo=hoo], %w[Set-Cookie ta=da]]

    assert_equal expected.sort, HTTP::Headers.coerce(hdrs).to_a.sort
  end

  def test_coerce_is_aliased_as_bracket
    result = HTTP::Headers["Content-Type" => "text/plain"]

    assert_instance_of HTTP::Headers, result
    assert_equal "text/plain", result["Content-Type"]
  end

  # -- .normalizer ------------------------------------------------------------

  def test_normalizer_returns_a_normalizer_instance
    assert_instance_of HTTP::Headers::Normalizer, HTTP::Headers.normalizer
  end

  def test_normalizer_returns_the_same_instance_on_subsequent_calls
    assert_same HTTP::Headers.normalizer, HTTP::Headers.normalizer
  end
end
