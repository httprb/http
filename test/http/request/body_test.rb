# frozen_string_literal: true

require "test_helper"

class HTTPRequestBodyTest < Minitest::Test
  cover "HTTP::Request::Body*"

  def build_body(source = "")
    HTTP::Request::Body.new(source)
  end

  # #initialize

  def test_initialize_when_body_is_nil_does_not_raise
    HTTP::Request::Body.new(nil)
  end

  def test_initialize_when_body_is_a_string_does_not_raise
    HTTP::Request::Body.new("string body")
  end

  def test_initialize_when_body_is_an_io_does_not_raise
    HTTP::Request::Body.new(FakeIO.new("IO body"))
  end

  def test_initialize_when_body_is_an_enumerable_does_not_raise
    HTTP::Request::Body.new(%w[bees cows])
  end

  def test_initialize_when_body_is_of_unrecognized_type_raises_error
    assert_raises(HTTP::RequestError) { HTTP::Request::Body.new(123) }
  end

  # #source

  def test_source_returns_the_original_object
    assert_equal "", build_body("").source
  end

  # #size

  def test_size_when_body_is_nil_returns_zero
    assert_equal 0, build_body(nil).size
  end

  def test_size_when_body_is_a_string_returns_string_bytesize
    assert_equal 21, build_body("\u041F\u0440\u0438\u0432\u0435\u0442, \u043C\u0438\u0440!").size
  end

  def test_size_when_body_is_an_io_with_size_returns_io_size
    assert_equal 7, build_body(FakeIO.new("content")).size
  end

  def test_size_when_body_is_an_io_without_size_raises_request_error
    assert_raises(HTTP::RequestError) { build_body(IO.pipe[0]).size }
  end

  def test_size_when_body_is_an_enumerable_raises_request_error
    assert_raises(HTTP::RequestError) { build_body(%w[bees cows]).size }
  end

  # #empty?

  def test_empty_when_body_is_nil_returns_true
    assert_predicate build_body(nil), :empty?
  end

  def test_empty_when_body_is_a_string_returns_false
    refute_predicate build_body("content"), :empty?
  end

  def test_empty_when_body_is_an_empty_string_returns_false
    refute_predicate build_body(""), :empty?
  end

  # #loggable?

  def test_loggable_when_body_is_a_text_string_returns_true
    assert_predicate build_body("text content"), :loggable?
  end

  def test_loggable_when_body_is_a_binary_encoded_string_returns_true
    assert_predicate build_body(String.new("\x89PNG\r\n", encoding: Encoding::BINARY)), :loggable?
  end

  def test_loggable_when_body_is_nil_returns_false
    refute_predicate build_body(nil), :loggable?
  end

  def test_loggable_when_body_is_an_io_returns_false
    refute_predicate build_body(FakeIO.new("IO body")), :loggable?
  end

  def test_loggable_when_body_is_an_enumerable_returns_false
    refute_predicate build_body(%w[bees cows]), :loggable?
  end

  # #each

  def test_each_when_body_is_nil_yields_nothing
    chunks = build_body(nil).enum_for(:each).map(&:dup)

    assert_equal [], chunks
  end

  def test_each_when_body_is_a_string_yields_the_string
    chunks = build_body("content").enum_for(:each).map(&:dup)

    assert_equal %w[content], chunks
  end

  def test_each_when_body_is_a_non_enumerable_io_yields_chunks_of_content
    body = FakeIO.new(("a" * 16 * 1024) + ("b" * 10 * 1024))
    chunks = build_body(body).enum_for(:each).map(&:dup)

    assert_equal ("a" * 16 * 1024) + ("b" * 10 * 1024), chunks.sum("")
  end

  def test_each_when_body_is_a_pipe_yields_chunks_of_content
    ios = IO.pipe
    subject = build_body(ios[0])

    writer = Thread.new(ios[1]) do |io|
      io << "abcdef"
      io.close
    end

    begin
      chunks = subject.enum_for(:each).map(&:dup)

      assert_equal "abcdef", chunks.sum("")
    ensure
      writer.join
    end
  end

  def test_each_when_body_is_an_enumerable_io_yields_chunks_of_content
    data = ("a" * 16 * 1024) + ("b" * 10 * 1024)
    chunks = build_body(StringIO.new(data)).enum_for(:each).map(&:dup)

    assert_equal data, chunks.sum("")
  end

  def test_each_when_body_is_an_enumerable_io_allows_multiple_enumerations
    data = ("a" * 16 * 1024) + ("b" * 10 * 1024)
    subject = build_body(StringIO.new(data))
    results = []

    2.times do
      result = ""
      subject.each { |chunk| result += chunk }
      results << result
    end

    assert_equal 2, results.count
    assert(results.all?(data))
  end

  def test_each_when_body_is_an_enumerable_yields_elements
    chunks = build_body(%w[bees cows]).enum_for(:each).map(&:dup)

    assert_equal %w[bees cows], chunks
  end

  # #==

  def test_eq_when_sources_are_equivalent_returns_true
    body1 = HTTP::Request::Body.new("content")
    body2 = HTTP::Request::Body.new("content")

    assert_equal body1, body2
  end

  def test_eq_compares_by_value_not_identity
    a = HTTP::Request::Body.new(+"same")
    b = HTTP::Request::Body.new(+"same")

    assert_equal a, b
  end

  def test_eq_uses_coercion_on_sources
    a = HTTP::Request::Body.new([1])
    b = HTTP::Request::Body.new([1.0])

    assert_equal a, b
  end

  def test_eq_when_sources_are_not_equivalent_returns_false
    body1 = HTTP::Request::Body.new("content")
    body2 = HTTP::Request::Body.new(nil)

    refute_equal body1, body2
  end

  def test_eq_when_objects_are_not_of_the_same_class_returns_false
    body1 = HTTP::Request::Body.new("content")
    body2 = "content"

    refute_equal body1, body2
  end

  def test_eq_when_sources_are_both_truthy_but_different_returns_false
    body1 = HTTP::Request::Body.new("alpha")
    body2 = HTTP::Request::Body.new("beta")

    refute_equal body1, body2
  end

  # #each return value

  def test_each_return_value_when_body_is_a_string_returns_self
    subject = build_body("content")

    assert_same(subject, subject.each { |_| nil })
  end

  def test_each_return_value_when_body_is_nil_returns_self
    subject = build_body(nil)

    assert_same(subject, subject.each { |_| nil })
  end

  def test_each_return_value_when_body_is_an_io_returns_self
    subject = build_body(StringIO.new("io content"))

    assert_same(subject, subject.each { |_| nil })
  end

  def test_each_return_value_when_body_is_an_enumerable_returns_self
    subject = build_body(%w[bees cows])

    assert_same(subject, subject.each { |_| nil })
  end

  # #size error messages

  def test_size_error_when_body_is_an_io_without_size_mentions_io_needing_size
    err = assert_raises(HTTP::RequestError) { build_body(IO.pipe[0]).size }
    assert_match(/IO object must respond to #size/, err.message)
  end

  def test_size_error_when_body_is_an_enumerable_mentions_undetermined_size
    body = %w[bees cows]
    err = assert_raises(HTTP::RequestError) { build_body(body).size }
    assert_match(/cannot determine size of body/, err.message)
    assert_includes err.message, body.inspect
    assert_match(/Content-Length/, err.message)
    assert_match(/chunked Transfer-Encoding/, err.message)
  end

  # #initialize error messages

  def test_initialize_error_when_body_is_of_unrecognized_type_mentions_wrong_type
    err = assert_raises(HTTP::RequestError) { HTTP::Request::Body.new(123) }
    assert_match(/body of wrong type/, err.message)
    assert_match(/Integer/, err.message)
  end

  # String subclass

  def test_string_subclass_does_not_raise_on_initialization
    string_subclass = Class.new(String)
    HTTP::Request::Body.new(string_subclass.new("subclass body"))
  end

  def test_string_subclass_returns_correct_size
    string_subclass = Class.new(String)

    assert_equal 13, build_body(string_subclass.new("subclass body")).size
  end

  def test_string_subclass_yields_the_string_in_each
    string_subclass = Class.new(String)
    subject = build_body(string_subclass.new("subclass body"))
    chunks = subject.enum_for(:each).map(&:dup)

    assert_equal ["subclass body"], chunks
  end

  def test_string_subclass_is_loggable
    string_subclass = Class.new(String)

    assert_predicate build_body(string_subclass.new("subclass body")), :loggable?
  end

  # Body subclass comparison

  def test_comparing_with_a_body_subclass_returns_true_for_equivalent
    subclass = Class.new(HTTP::Request::Body)
    body1 = HTTP::Request::Body.new("content")
    body2 = subclass.new("content")

    assert_equal body1, body2
  end

  # ProcIO

  def test_proc_io_write_calls_the_block_with_data_and_returns_bytesize
    received = nil
    block = proc { |data| received = data }
    proc_io = HTTP::Request::Body::ProcIO.new(block)

    result = proc_io.write("hello")

    assert_equal "hello", received
    assert_equal 5, result
  end

  def test_proc_io_write_returns_correct_bytesize_for_multibyte_strings
    block = proc { |_| }
    proc_io = HTTP::Request::Body::ProcIO.new(block)

    # "Привет" is 12 bytes in UTF-8
    result = proc_io.write("\u041F\u0440\u0438\u0432\u0435\u0442")

    assert_equal 12, result
  end
end
