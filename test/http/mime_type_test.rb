# frozen_string_literal: true

require "test_helper"
require "securerandom"

class HTTPMimeTypeTest < Minitest::Test
  cover "HTTP::MimeType*"

  def sample_type
    @sample_type ||= "application/mutant-check-#{SecureRandom.hex(4)}"
  end

  def sample_adapter
    @sample_adapter ||= Module.new do
      def self.encode(obj); end

      def self.decode(str); end
    end
  end

  def test_register_adapter_stores_the_adapter_retrievable_via_brackets
    HTTP::MimeType.register_adapter(sample_type, sample_adapter)

    assert_same sample_adapter, HTTP::MimeType[sample_type]
  end

  def test_register_adapter_calls_to_s_on_the_type_argument
    type_str = "application/test-to-s-#{SecureRandom.hex(4)}"
    type_obj = fake(to_s: type_str)

    HTTP::MimeType.register_adapter(type_obj, sample_adapter)

    assert_same sample_adapter, HTTP::MimeType[type_str]
  end

  def test_brackets_retrieves_a_registered_adapter
    HTTP::MimeType.register_adapter(sample_type, sample_adapter)

    assert_same sample_adapter, HTTP::MimeType[sample_type]
  end

  def test_brackets_raises_unsupported_mime_type_error_for_unknown_type
    assert_raises(HTTP::UnsupportedMimeTypeError) do
      HTTP::MimeType["application/nonexistent-#{SecureRandom.hex(4)}"]
    end
  end

  def test_brackets_includes_the_type_in_the_error_message
    unknown = "application/unknown-#{SecureRandom.hex(4)}"

    err = assert_raises(HTTP::UnsupportedMimeTypeError) do
      HTTP::MimeType[unknown]
    end
    assert_includes err.message, unknown
  end

  def test_brackets_resolves_aliases_when_looking_up_adapters
    shortcut = :"test_shortcut_#{SecureRandom.hex(4)}"
    HTTP::MimeType.register_adapter(sample_type, sample_adapter)
    HTTP::MimeType.register_alias(sample_type, shortcut)

    assert_same sample_adapter, HTTP::MimeType[shortcut]
  end

  def test_register_alias_stores_alias_resolvable_via_normalize
    shortcut = :"test_alias_#{SecureRandom.hex(4)}"
    HTTP::MimeType.register_alias(sample_type, shortcut)

    assert_equal sample_type, HTTP::MimeType.normalize(shortcut)
  end

  def test_register_alias_calls_to_sym_on_the_shortcut_argument
    shortcut_str = "test_sym_shortcut_#{SecureRandom.hex(4)}"
    HTTP::MimeType.register_alias(sample_type, shortcut_str)

    assert_equal sample_type, HTTP::MimeType.normalize(shortcut_str.to_sym)
  end

  def test_register_alias_calls_to_s_on_the_type_argument
    type_str = "application/test-alias-to-s-#{SecureRandom.hex(4)}"
    type_obj = fake(to_s: type_str)

    shortcut = :"test_alias_to_s_#{SecureRandom.hex(4)}"
    HTTP::MimeType.register_alias(type_obj, shortcut)

    assert_equal type_str, HTTP::MimeType.normalize(shortcut)
  end

  def test_normalize_returns_the_type_string_if_no_alias_found
    unaliased = "application/no-alias-#{SecureRandom.hex(4)}"

    assert_equal unaliased, HTTP::MimeType.normalize(unaliased)
  end

  def test_normalize_returns_aliased_type_if_alias_exists
    shortcut = :"test_norm_#{SecureRandom.hex(4)}"
    HTTP::MimeType.register_alias(sample_type, shortcut)

    assert_equal sample_type, HTTP::MimeType.normalize(shortcut)
  end

  def test_normalize_calls_to_s_on_the_argument_when_no_alias_found
    type_str = "application/normalize-to-s-#{SecureRandom.hex(4)}"
    type_obj = fake(to_s: type_str)

    assert_equal type_str, HTTP::MimeType.normalize(type_obj)
  end

  def test_adapters_initializes_as_a_hash_when_accessed_for_the_first_time
    original = HTTP::MimeType.instance_variable_get(:@adapters)
    HTTP::MimeType.instance_variable_set(:@adapters, nil)
    begin
      result = HTTP::MimeType.send(:adapters)

      assert_instance_of Hash, result
    ensure
      HTTP::MimeType.instance_variable_set(:@adapters, original)
    end
  end

  def test_aliases_initializes_as_a_hash_when_accessed_for_the_first_time
    original = HTTP::MimeType.instance_variable_get(:@aliases)
    HTTP::MimeType.instance_variable_set(:@aliases, nil)
    begin
      result = HTTP::MimeType.send(:aliases)

      assert_instance_of Hash, result
    ensure
      HTTP::MimeType.instance_variable_set(:@aliases, original)
    end
  end

  def test_adapter_raises_error_on_encode_with_class_name_in_message
    err = assert_raises(HTTP::Error) { HTTP::MimeType::Adapter.instance.encode("data") }
    assert_equal "HTTP::MimeType::Adapter does not supports #encode", err.message
  end

  def test_adapter_raises_error_on_decode_with_class_name_in_message
    err = assert_raises(HTTP::Error) { HTTP::MimeType::Adapter.instance.decode("data") }
    assert_equal "HTTP::MimeType::Adapter does not supports #decode", err.message
  end

  def test_builtin_has_json_adapter_registered_for_application_json
    assert_equal HTTP::MimeType::JSON, HTTP::MimeType["application/json"]
  end

  def test_builtin_has_json_alias_for_application_json
    assert_equal "application/json", HTTP::MimeType.normalize(:json)
  end
end
