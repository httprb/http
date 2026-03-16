# frozen_string_literal: true

require "test_helper"

class HTTPContentTypeTest < Minitest::Test
  cover "HTTP::ContentType*"

  # -- .parse -----------------------------------------------------------------

  def test_parse_text_plain_has_correct_mime_type
    ct = HTTP::ContentType.parse "text/plain"

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_text_plain_has_correct_charset
    ct = HTTP::ContentType.parse "text/plain"

    assert_nil ct.charset
  end

  def test_parse_mixed_case_text_plain_has_correct_mime_type
    ct = HTTP::ContentType.parse "tEXT/plaIN"

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_mixed_case_text_plain_has_correct_charset
    ct = HTTP::ContentType.parse "tEXT/plaIN"

    assert_nil ct.charset
  end

  def test_parse_text_plain_with_charset_has_correct_mime_type
    ct = HTTP::ContentType.parse "text/plain; charset=utf-8"

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_text_plain_with_charset_has_correct_charset
    ct = HTTP::ContentType.parse "text/plain; charset=utf-8"

    assert_equal "utf-8", ct.charset
  end

  def test_parse_text_plain_with_quoted_charset_has_correct_mime_type
    ct = HTTP::ContentType.parse 'text/plain; charset="utf-8"'

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_text_plain_with_quoted_charset_has_correct_charset
    ct = HTTP::ContentType.parse 'text/plain; charset="utf-8"'

    assert_equal "utf-8", ct.charset
  end

  def test_parse_text_plain_with_mixed_case_charset_has_correct_mime_type
    ct = HTTP::ContentType.parse "text/plain; charSET=utf-8"

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_text_plain_with_mixed_case_charset_has_correct_charset
    ct = HTTP::ContentType.parse "text/plain; charSET=utf-8"

    assert_equal "utf-8", ct.charset
  end

  def test_parse_with_extra_params_has_correct_mime_type
    ct = HTTP::ContentType.parse "text/plain; foo=bar; charset=utf-8"

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_with_extra_params_has_correct_charset
    ct = HTTP::ContentType.parse "text/plain; foo=bar; charset=utf-8"

    assert_equal "utf-8", ct.charset
  end

  def test_parse_with_no_spaces_has_correct_mime_type
    ct = HTTP::ContentType.parse "text/plain;charset=utf-8;foo=bar"

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_with_no_spaces_has_correct_charset
    ct = HTTP::ContentType.parse "text/plain;charset=utf-8;foo=bar"

    assert_equal "utf-8", ct.charset
  end

  def test_parse_nil_returns_nil_mime_type
    ct = HTTP::ContentType.parse nil

    assert_nil ct.mime_type
  end

  def test_parse_nil_returns_nil_charset
    ct = HTTP::ContentType.parse nil

    assert_nil ct.charset
  end

  def test_parse_empty_string_returns_nil_mime_type
    ct = HTTP::ContentType.parse ""

    assert_nil ct.mime_type
  end

  def test_parse_empty_string_returns_nil_charset
    ct = HTTP::ContentType.parse ""

    assert_nil ct.charset
  end

  def test_parse_with_whitespace_strips_whitespace_from_mime_type
    ct = HTTP::ContentType.parse " text/plain ; charset= utf-8 "

    assert_equal "text/plain", ct.mime_type
  end

  def test_parse_with_whitespace_strips_whitespace_from_charset
    ct = HTTP::ContentType.parse " text/plain ; charset= utf-8 "

    assert_equal "utf-8", ct.charset
  end

  # -- #deconstruct_keys ------------------------------------------------------

  def test_deconstruct_keys_returns_all_keys_when_given_nil
    ct = HTTP::ContentType.new("text/html", "utf-8")

    assert_equal({ mime_type: "text/html", charset: "utf-8" }, ct.deconstruct_keys(nil))
  end

  def test_deconstruct_keys_returns_only_requested_keys
    ct = HTTP::ContentType.new("text/html", "utf-8")

    assert_equal({ mime_type: "text/html" }, ct.deconstruct_keys([:mime_type]))
  end

  def test_deconstruct_keys_excludes_unrequested_keys
    ct = HTTP::ContentType.new("text/html", "utf-8")

    refute_includes ct.deconstruct_keys([:mime_type]).keys, :charset
  end

  def test_deconstruct_keys_returns_empty_hash_for_empty_keys
    ct = HTTP::ContentType.new("text/html", "utf-8")

    assert_equal({}, ct.deconstruct_keys([]))
  end

  def test_deconstruct_keys_returns_nil_values_when_attributes_are_nil
    ct = HTTP::ContentType.new

    assert_equal({ mime_type: nil, charset: nil }, ct.deconstruct_keys(nil))
  end

  def test_deconstruct_keys_supports_pattern_matching_with_case_in
    ct = HTTP::ContentType.new("text/html", "utf-8")

    matched = case ct
              in { mime_type: /html/ }
                true
              else
                false
              end

    assert matched
  end

  # -- #initialize ------------------------------------------------------------

  def test_initialize_stores_mime_type_and_charset
    ct = HTTP::ContentType.new("text/html", "utf-8")

    assert_equal "text/html", ct.mime_type
    assert_equal "utf-8", ct.charset
  end

  def test_initialize_defaults_to_nil
    ct = HTTP::ContentType.new

    assert_nil ct.mime_type
    assert_nil ct.charset
  end
end
