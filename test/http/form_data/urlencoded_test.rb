# frozen_string_literal: true

require "test_helper"

class FormDataUrlencodedTest < Minitest::Test
  cover "HTTP::FormData::Urlencoded*"

  def test_raises_error_for_non_enumerable_input
    assert_raises(HTTP::FormData::Error) { HTTP::FormData::Urlencoded.new(42) }
  end

  def test_raises_argument_error_for_non_hash_top_level
    assert_raises(ArgumentError) { HTTP::FormData::Urlencoded.encoder.call(42) }
  end

  def test_supports_enumerables_of_pairs
    form_data = HTTP::FormData::Urlencoded.new([%w[foo bar], ["foo", %w[baz moo]]])

    assert_equal "foo=bar&foo[]=baz&foo[]=moo", form_data.to_s
  end

  def test_content_type
    assert_equal "application/x-www-form-urlencoded", HTTP::FormData::Urlencoded.new({ foo: "bar" }).content_type
  end

  def test_content_length
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" })

    assert_equal form_data.to_s.bytesize, form_data.content_length
  end

  def test_content_length_with_unicode
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "тест" })

    assert_equal form_data.to_s.bytesize, form_data.content_length
  end

  def test_to_s
    assert_equal "foo%5Bbar%5D=test", HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" }).to_s
  end

  def test_to_s_with_unicode
    assert_equal "foo%5Bbar%5D=%D1%82%D0%B5%D1%81%D1%82",
                 HTTP::FormData::Urlencoded.new({ "foo[bar]" => "тест" }).to_s
  end

  def test_to_s_with_nested_hashes
    assert_equal "foo[bar]=test", HTTP::FormData::Urlencoded.new({ "foo" => { "bar" => "test" } }).to_s
  end

  def test_to_s_with_nil_value
    assert_equal "foo", HTTP::FormData::Urlencoded.new({ "foo" => nil }).to_s
  end

  def test_to_s_rewinds_content
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" })
    content = form_data.read

    assert_equal content, form_data.to_s
    assert_equal content, form_data.read
  end

  def test_size
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" })

    assert_equal form_data.to_s.bytesize, form_data.size
  end

  def test_read
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" })

    assert_equal form_data.to_s, form_data.read
  end

  def test_rewind
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" })
    form_data.read
    form_data.rewind

    assert_equal form_data.to_s, form_data.read
  end

  # --- Custom encoders ---

  def test_custom_class_level_encoder
    original_encoder = HTTP::FormData::Urlencoded.encoder
    HTTP::FormData::Urlencoded.encoder = JSON.method(:dump)
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" })

    assert_equal '{"foo[bar]":"test"}', form_data.to_s
  ensure
    HTTP::FormData::Urlencoded.encoder = original_encoder
  end

  def test_encoder_rejects_non_callable
    assert_raises(ArgumentError) { HTTP::FormData::Urlencoded.encoder = "not callable" }
  end

  def test_custom_instance_level_encoder
    encoder = proc { |data| JSON.dump(data) }
    form_data = HTTP::FormData::Urlencoded.new({ "foo[bar]" => "test" }, encoder: encoder)

    assert_equal '{"foo[bar]":"test"}', form_data.to_s
  end

  def test_default_encoder_returns_callable
    assert_respond_to HTTP::FormData::Urlencoded.encoder, :call
  end

  def test_default_encoder_encodes_correctly
    assert_equal "key=value", HTTP::FormData::Urlencoded.encoder.call({ "key" => "value" })
  end

  def test_nil_encoder_uses_class_default
    form_data = HTTP::FormData::Urlencoded.new({ foo: "bar" }, encoder: nil)

    assert_equal "foo=bar", form_data.to_s
  end

  def test_custom_encoder_is_called
    calls = []
    custom = proc { |data|
      calls << data
      "custom"
    }
    form_data = HTTP::FormData::Urlencoded.new({ a: "b" }, encoder: custom)

    assert_equal "custom", form_data.to_s
    refute_empty calls
  end

  # --- Initialize edge cases ---

  def test_initialize_with_nil_data
    assert_equal "", HTTP::FormData::Urlencoded.new(nil).to_s
  end

  def test_initialize_with_to_h_object
    obj = Object.new
    def obj.to_h = { x: "y" }

    assert_equal "x=y", HTTP::FormData::Urlencoded.new(obj).to_s
  end

  def test_initialize_stores_encoded_content
    form_data = HTTP::FormData::Urlencoded.new({ a: "1", b: "2" })

    assert_equal "a=1&b=2", form_data.to_s
    assert_equal 7, form_data.size
  end

  def test_read_with_length
    form_data = HTTP::FormData::Urlencoded.new({ foo: "bar" })

    assert_equal "fo", form_data.read(2)
    assert_equal "o=b", form_data.read(3)
    assert_equal "ar", form_data.read(5)
    assert_nil form_data.read(1)
  end

  def test_read_with_nil_length
    assert_equal "foo=bar", HTTP::FormData::Urlencoded.new({ foo: "bar" }).read(nil)
  end
end
