# frozen_string_literal: true

require "test_helper"
require "securerandom"

describe HTTP::MimeType do
  cover "HTTP::MimeType*"

  let(:sample_type) { "application/mutant-check-#{SecureRandom.hex(4)}" }
  let(:sample_adapter) do
    Module.new do
      def self.encode(obj); end

      def self.decode(str); end
    end
  end

  describe ".register_adapter" do
    it "stores the adapter retrievable via []" do
      HTTP::MimeType.register_adapter(sample_type, sample_adapter)

      assert_same sample_adapter, HTTP::MimeType[sample_type]
    end

    it "calls .to_s on the type argument" do
      type_str = "application/test-to-s-#{SecureRandom.hex(4)}"
      type_obj = fake(to_s: type_str)

      HTTP::MimeType.register_adapter(type_obj, sample_adapter)

      assert_same sample_adapter, HTTP::MimeType[type_str]
    end
  end

  describe ".[]" do
    it "retrieves a registered adapter" do
      HTTP::MimeType.register_adapter(sample_type, sample_adapter)

      assert_same sample_adapter, HTTP::MimeType[sample_type]
    end

    it "raises UnsupportedMimeTypeError for unknown type" do
      assert_raises(HTTP::UnsupportedMimeTypeError) do
        HTTP::MimeType["application/nonexistent-#{SecureRandom.hex(4)}"]
      end
    end

    it "includes the type in the error message" do
      unknown = "application/unknown-#{SecureRandom.hex(4)}"

      err = assert_raises(HTTP::UnsupportedMimeTypeError) do
        HTTP::MimeType[unknown]
      end
      assert_includes err.message, unknown
    end

    it "resolves aliases when looking up adapters" do
      shortcut = :"test_shortcut_#{SecureRandom.hex(4)}"
      HTTP::MimeType.register_adapter(sample_type, sample_adapter)
      HTTP::MimeType.register_alias(sample_type, shortcut)

      assert_same sample_adapter, HTTP::MimeType[shortcut]
    end
  end

  describe ".register_alias" do
    it "stores alias resolvable via normalize" do
      shortcut = :"test_alias_#{SecureRandom.hex(4)}"
      HTTP::MimeType.register_alias(sample_type, shortcut)

      assert_equal sample_type, HTTP::MimeType.normalize(shortcut)
    end

    it "calls .to_sym on the shortcut argument" do
      shortcut_str = "test_sym_shortcut_#{SecureRandom.hex(4)}"
      HTTP::MimeType.register_alias(sample_type, shortcut_str)

      assert_equal sample_type, HTTP::MimeType.normalize(shortcut_str.to_sym)
    end

    it "calls .to_s on the type argument" do
      type_str = "application/test-alias-to-s-#{SecureRandom.hex(4)}"
      type_obj = fake(to_s: type_str)

      shortcut = :"test_alias_to_s_#{SecureRandom.hex(4)}"
      HTTP::MimeType.register_alias(type_obj, shortcut)

      assert_equal type_str, HTTP::MimeType.normalize(shortcut)
    end
  end

  describe ".normalize" do
    it "returns the type string if no alias found" do
      unaliased = "application/no-alias-#{SecureRandom.hex(4)}"

      assert_equal unaliased, HTTP::MimeType.normalize(unaliased)
    end

    it "returns aliased type if alias exists" do
      shortcut = :"test_norm_#{SecureRandom.hex(4)}"
      HTTP::MimeType.register_alias(sample_type, shortcut)

      assert_equal sample_type, HTTP::MimeType.normalize(shortcut)
    end

    it "calls .to_s on the argument when no alias found" do
      type_str = "application/normalize-to-s-#{SecureRandom.hex(4)}"
      type_obj = fake(to_s: type_str)

      assert_equal type_str, HTTP::MimeType.normalize(type_obj)
    end
  end

  describe ".adapters" do
    it "initializes as a Hash when accessed for the first time" do
      original = HTTP::MimeType.instance_variable_get(:@adapters)
      HTTP::MimeType.instance_variable_set(:@adapters, nil)
      begin
        result = HTTP::MimeType.send(:adapters)

        assert_instance_of Hash, result
      ensure
        HTTP::MimeType.instance_variable_set(:@adapters, original)
      end
    end
  end

  describe ".aliases" do
    it "initializes as a Hash when accessed for the first time" do
      original = HTTP::MimeType.instance_variable_get(:@aliases)
      HTTP::MimeType.instance_variable_set(:@aliases, nil)
      begin
        result = HTTP::MimeType.send(:aliases)

        assert_instance_of Hash, result
      ensure
        HTTP::MimeType.instance_variable_set(:@aliases, original)
      end
    end
  end

  describe "built-in JSON registration" do
    it "has JSON adapter registered for application/json" do
      assert_equal HTTP::MimeType::JSON, HTTP::MimeType["application/json"]
    end

    it "has :json alias for application/json" do
      assert_equal "application/json", HTTP::MimeType.normalize(:json)
    end
  end
end
