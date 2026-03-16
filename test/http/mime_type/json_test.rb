# frozen_string_literal: true

require "test_helper"

class HTTPMimeTypeJSONTest < Minitest::Test
  cover "HTTP::MimeType*"

  def adapter
    @adapter ||= HTTP::MimeType::JSON.send(:new)
  end

  def test_encode_uses_to_json_when_available
    assert_equal '{"foo":"bar"}', adapter.encode(foo: "bar")
  end

  def test_encode_prefers_to_json_over_json_dump
    obj = Object.new
    def obj.to_json(*args)
      args.empty? ? '"direct"' : '"via_dump"'
    end

    assert_equal '"direct"', adapter.encode(obj)
  end

  def test_encode_falls_back_to_json_dump_for_objects_without_to_json
    obj = Object.new
    obj.define_singleton_method(:respond_to?) do |method, *args|
      return false if method == :to_json

      super(method, *args)
    end

    assert_kind_of String, adapter.encode(obj)
  end

  def test_decode_parses_json_strings
    assert_equal({ "foo" => "bar" }, adapter.decode('{"foo":"bar"}'))
  end
end
