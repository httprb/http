# frozen_string_literal: true

require "test_helper"

class HTTPURINormalizerTest < Minitest::Test
  def test_scheme_lower_cases_scheme
    assert_equal "http", HTTP::URI::NORMALIZER.call("HttP://example.com").scheme
  end

  def test_hostname_lower_cases_hostname
    assert_equal "example.com", HTTP::URI::NORMALIZER.call("http://EXAMPLE.com").host
  end

  def test_hostname_decodes_percent_encoded_hostname
    assert_equal "example.com", HTTP::URI::NORMALIZER.call("http://ex%61mple.com").host
  end

  def test_hostname_removes_trailing_period_in_hostname
    assert_equal "example.com", HTTP::URI::NORMALIZER.call("http://example.com.").host
  end

  def test_hostname_idn_encodes_non_ascii_hostname
    assert_equal "xn--exmple-cua.com", HTTP::URI::NORMALIZER.call("http://ex\u00E4mple.com").host
  end

  def test_path_ensures_path_is_not_empty
    assert_equal "/", HTTP::URI::NORMALIZER.call("http://example.com").path
  end

  def test_path_preserves_double_slashes_in_path
    assert_equal "//a///b", HTTP::URI::NORMALIZER.call("http://example.com//a///b").path
  end

  def test_path_resolves_single_dot_segments_in_path
    assert_equal "/a/b", HTTP::URI::NORMALIZER.call("http://example.com/a/./b").path
  end

  def test_path_resolves_double_dot_segments_in_path
    assert_equal "/a/c", HTTP::URI::NORMALIZER.call("http://example.com/a/b/../c").path
  end

  def test_path_resolves_leading_double_dot_segments_in_path
    assert_equal "/a/b", HTTP::URI::NORMALIZER.call("http://example.com/../a/b").path
  end

  def test_path_percent_encodes_control_characters_in_path
    assert_equal "/%00%7F%0A", HTTP::URI::NORMALIZER.call("http://example.com/\x00\x7F\n").path
  end

  def test_path_percent_encodes_space_in_path
    assert_equal "/a%20b", HTTP::URI::NORMALIZER.call("http://example.com/a b").path
  end

  def test_path_percent_encodes_non_ascii_characters_in_path
    assert_equal "/%E3%82%AD%E3%83%A7", HTTP::URI::NORMALIZER.call("http://example.com/\u30AD\u30E7").path
  end

  def test_path_does_not_percent_encode_non_special_characters_in_path
    assert_equal "/~.-_!$&()*,;=:@{}", HTTP::URI::NORMALIZER.call("http://example.com/~.-_!$&()*,;=:@{}").path
  end

  def test_path_preserves_escape_sequences_in_path
    assert_equal "/%41", HTTP::URI::NORMALIZER.call("http://example.com/%41").path
  end

  def test_query_allows_no_query
    assert_nil HTTP::URI::NORMALIZER.call("http://example.com").query
  end

  def test_query_percent_encodes_control_characters_in_query
    assert_equal "%00%7F%0A", HTTP::URI::NORMALIZER.call("http://example.com/?\x00\x7F\n").query
  end

  def test_query_percent_encodes_space_in_query
    assert_equal "a%20b", HTTP::URI::NORMALIZER.call("http://example.com/?a b").query
  end

  def test_query_percent_encodes_non_ascii_characters_in_query
    assert_equal "%E3%82%AD%E3%83%A7", HTTP::URI::NORMALIZER.call("http://example.com?\u30AD\u30E7").query
  end

  def test_query_does_not_percent_encode_non_special_characters_in_query
    assert_equal "~.-_!$&()*,;=:@{}?", HTTP::URI::NORMALIZER.call("http://example.com/?~.-_!$&()*,;=:@{}?").query
  end

  def test_query_preserves_escape_sequences_in_query
    assert_equal "%41", HTTP::URI::NORMALIZER.call("http://example.com/?%41").query
  end
end
