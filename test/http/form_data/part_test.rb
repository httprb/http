# frozen_string_literal: true

require "test_helper"

class FormDataPartTest < Minitest::Test
  cover "HTTP::FormData::Part*"

  def test_size
    assert_equal 20, HTTP::FormData::Part.new("привет мир!").size
  end

  def test_to_s
    assert_equal "привет мир!", HTTP::FormData::Part.new("привет мир!").to_s
  end

  def test_to_s_rewinds_content
    part = HTTP::FormData::Part.new("привет мир!")
    part.to_s
    content = part.read

    assert_equal content, part.to_s
    assert_equal content, part.read
  end

  def test_read
    assert_equal "привет мир!", HTTP::FormData::Part.new("привет мир!").read
  end

  def test_read_with_length
    part = HTTP::FormData::Part.new("hello world")

    assert_equal "hello", part.read(5)
    assert_equal " worl", part.read(5)
    assert_equal "d", part.read(5)
    assert_nil part.read(5)
  end

  def test_read_with_nil_length
    assert_equal "hello", HTTP::FormData::Part.new("hello").read(nil)
  end

  def test_read_with_outbuf
    part = HTTP::FormData::Part.new("hello")
    buf = +""
    result = part.read(3, buf)

    assert_equal "hel", result
    assert_equal "hel", buf
  end

  def test_rewind
    part = HTTP::FormData::Part.new("привет мир!")
    part.read
    part.rewind

    assert_equal "привет мир!", part.read
  end

  def test_filename_defaults_to_nil
    assert_nil HTTP::FormData::Part.new("").filename
  end

  def test_filename_with_option
    assert_equal "foobar.txt", HTTP::FormData::Part.new("", filename: "foobar.txt").filename
  end

  def test_filename_stores_exact_value
    assert_equal "test.txt", HTTP::FormData::Part.new("body", filename: "test.txt").filename
  end

  def test_content_type_defaults_to_nil
    assert_nil HTTP::FormData::Part.new("").content_type
  end

  def test_content_type_with_option
    assert_equal "application/json", HTTP::FormData::Part.new("", content_type: "application/json").content_type
  end

  def test_content_type_stores_exact_value
    assert_equal "text/plain", HTTP::FormData::Part.new("body", content_type: "text/plain").content_type
  end

  def test_initialize_converts_body_to_string
    assert_equal "42", HTTP::FormData::Part.new(42).to_s
  end

  def test_initialize_with_symbol_body
    assert_equal "hello", HTTP::FormData::Part.new(:hello).to_s
  end
end
