# frozen_string_literal: true

require "test_helper"

class FormDataTest < Minitest::Test
  cover "HTTP::FormData*"

  def fixture_path
    @fixture_path ||= Pathname.new(__dir__).join("form_data/fixtures/the-http-gem.info").realpath
  end

  # --- create ---

  def test_create_returns_urlencoded_when_no_files
    assert_instance_of HTTP::FormData::Urlencoded, HTTP::FormData.create({ foo: :bar })
  end

  def test_create_returns_multipart_when_file_param
    file = HTTP::FormData::File.new(fixture_path.to_s)

    assert_instance_of HTTP::FormData::Multipart, HTTP::FormData.create({ foo: :bar, baz: file })
  end

  def test_create_returns_multipart_when_file_in_array_param
    file = HTTP::FormData::File.new(fixture_path.to_s)

    assert_instance_of HTTP::FormData::Multipart, HTTP::FormData.create({ foo: :bar, baz: [file] })
  end

  def test_create_returns_empty_urlencoded_for_nil_data
    result = HTTP::FormData.create(nil)

    assert_instance_of HTTP::FormData::Urlencoded, result
    assert_equal "", result.to_s
  end

  def test_create_includes_file_content_in_multipart
    file = HTTP::FormData::File.new(StringIO.new("file content"))
    result = HTTP::FormData.create({ name: file })

    assert_instance_of HTTP::FormData::Multipart, result
    assert_includes result.to_s, "file content"
  end

  def test_create_encodes_urlencoded_content
    result = HTTP::FormData.create({ foo: "bar" })

    assert_instance_of HTTP::FormData::Urlencoded, result
    assert_equal "foo=bar", result.to_s
  end

  def test_create_passes_encoder_to_urlencoded
    custom_encoder = proc { |data| data.map { |k, v| "#{k}:#{v}" }.join(",") }
    result = HTTP::FormData.create({ foo: "bar" }, encoder: custom_encoder)

    assert_instance_of HTTP::FormData::Urlencoded, result
    assert_equal "foo:bar", result.to_s
  end

  def test_create_accepts_to_h_objects
    obj = Object.new
    def obj.to_h = { foo: "bar" }

    result = HTTP::FormData.create(obj)

    assert_instance_of HTTP::FormData::Urlencoded, result
    assert_equal "foo=bar", result.to_s
  end

  # --- multipart? detection ---

  def test_string_values_are_not_multipart
    assert_instance_of HTTP::FormData::Urlencoded, HTTP::FormData.create({ foo: "bar", baz: "qux" })
  end

  def test_array_of_strings_is_not_multipart
    assert_instance_of HTTP::FormData::Urlencoded, HTTP::FormData.create({ foo: %w[bar baz] })
  end

  def test_empty_array_is_not_multipart
    assert_instance_of HTTP::FormData::Urlencoded, HTTP::FormData.create({ foo: [] })
  end

  def test_part_value_is_multipart
    part = HTTP::FormData::Part.new("hello", content_type: "text/plain")

    assert_instance_of HTTP::FormData::Multipart, HTTP::FormData.create({ foo: part })
  end

  def test_array_containing_part_is_multipart
    part = HTTP::FormData::Part.new("hello", content_type: "text/plain")

    assert_instance_of HTTP::FormData::Multipart, HTTP::FormData.create({ foo: [part] })
  end

  def test_to_ary_containing_part_is_multipart
    part = HTTP::FormData::Part.new("hello")
    obj = Object.new
    obj.define_singleton_method(:to_ary) { [part] }

    assert_instance_of HTTP::FormData::Multipart, HTTP::FormData.create({ foo: obj })
  end

  def test_create_multipart_preserves_all_params
    file = HTTP::FormData::File.new(StringIO.new("content"))
    body = HTTP::FormData.create({ user: "ixti", file: file }).to_s

    assert_includes body, "ixti"
    assert_includes body, "content"
    assert_includes body, "user"
    assert_includes body, "file"
  end

  # --- ensure_data ---

  def test_ensure_data_with_hash
    assert_equal({ foo: :bar }, HTTP::FormData.ensure_data({ foo: :bar }))
  end

  def test_ensure_data_with_array
    data = [%i[foo bar], %i[foo baz]]

    assert_equal data, HTTP::FormData.ensure_data(data)
  end

  def test_ensure_data_with_enumerator
    assert_instance_of Enumerator, HTTP::FormData.ensure_data(Enumerator.new { |y| y << %i[foo bar] })
  end

  def test_ensure_data_with_to_h
    obj = Object.new
    def obj.to_h = { foo: :bar }

    assert_equal({ foo: :bar }, HTTP::FormData.ensure_data(obj))
  end

  def test_ensure_data_with_nil
    result = HTTP::FormData.ensure_data(nil)

    assert_instance_of Array, result
    assert_empty result
  end

  def test_ensure_data_with_invalid_input
    error = assert_raises(HTTP::FormData::Error) { HTTP::FormData.ensure_data(42) }

    assert_includes error.message, "42"
    assert_includes error.message, "is neither Enumerable nor responds to :to_h"
  end

  def test_ensure_data_with_false_raises
    assert_raises(HTTP::FormData::Error) { HTTP::FormData.ensure_data(false) }
  end

  def test_ensure_data_returns_same_array_object
    input = [%i[foo bar]]

    assert_same input, HTTP::FormData.ensure_data(input)
  end

  def test_ensure_data_returns_same_hash_object
    input = { foo: :bar }

    assert_same input, HTTP::FormData.ensure_data(input)
  end

  def test_ensure_data_error_message_uses_inspect
    obj = Object.new
    def obj.inspect = "CUSTOM_INSPECT"
    def obj.to_s = "CUSTOM_TO_S"

    error = assert_raises(HTTP::FormData::Error) { HTTP::FormData.ensure_data(obj) }

    assert_includes error.message, "CUSTOM_INSPECT"
    refute_includes error.message, "CUSTOM_TO_S"
  end

  # --- ensure_hash ---

  def test_ensure_hash_with_hash
    assert_equal({ foo: :bar }, HTTP::FormData.ensure_hash({ foo: :bar }))
  end

  def test_ensure_hash_with_to_h
    obj = Object.new
    def obj.to_h = { foo: :bar }

    assert_equal({ foo: :bar }, HTTP::FormData.ensure_hash(obj))
  end

  def test_ensure_hash_with_nil
    result = HTTP::FormData.ensure_hash(nil)

    assert_instance_of Hash, result
    assert_empty result
  end

  def test_ensure_hash_with_invalid_input
    error = assert_raises(HTTP::FormData::Error) { HTTP::FormData.ensure_hash(42) }

    assert_includes error.message, "42"
    assert_includes error.message, "is neither Hash nor responds to :to_h"
  end

  def test_ensure_hash_with_hash_subclass
    subclass = Class.new(Hash)
    obj = subclass.new
    obj[:foo] = :bar

    assert_same obj, HTTP::FormData.ensure_hash(obj)
  end

  def test_ensure_hash_returns_same_hash_object
    input = { foo: :bar }

    assert_same input, HTTP::FormData.ensure_hash(input)
  end

  def test_ensure_hash_with_false_raises
    assert_raises(HTTP::FormData::Error) { HTTP::FormData.ensure_hash(false) }
  end

  def test_ensure_hash_error_message_uses_inspect
    obj = Object.new
    def obj.inspect = "HASH_INSPECT"
    def obj.to_s = "HASH_TO_S"

    error = assert_raises(HTTP::FormData::Error) { HTTP::FormData.ensure_hash(obj) }

    assert_includes error.message, "HASH_INSPECT"
  end
end
