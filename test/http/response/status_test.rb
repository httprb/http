# frozen_string_literal: true

require "test_helper"

class HTTPResponseStatusTest < Minitest::Test
  cover "HTTP::Response::Status*"

  # ---------------------------------------------------------------------------
  # .new
  # ---------------------------------------------------------------------------
  def test_new_fails_if_given_value_does_not_respond_to_to_i
    assert_raises(TypeError) { HTTP::Response::Status.new(Object.new) }
  end

  def test_new_accepts_any_object_that_responds_to_to_i
    HTTP::Response::Status.new(fake(to_i: 200))
  end

  # ---------------------------------------------------------------------------
  # #code
  # ---------------------------------------------------------------------------
  def test_code_returns_the_integer_code
    status = HTTP::Response::Status.new("200.0")

    assert_equal 200, status.code
  end

  def test_code_is_an_integer
    status = HTTP::Response::Status.new("200.0")

    assert_kind_of Integer, status.code
  end

  # ---------------------------------------------------------------------------
  # #reason
  # ---------------------------------------------------------------------------
  def test_reason_with_unknown_code_returns_nil
    assert_nil HTTP::Response::Status.new(1024).reason
  end

  HTTP::Response::Status::REASONS.each do |code, reason|
    define_method(:"test_reason_#{code}_returns_#{reason.downcase.gsub(/[^a-z0-9]/, '_')}") do
      assert_equal reason, HTTP::Response::Status.new(code).reason
    end

    define_method(:"test_reason_#{code}_is_frozen") do
      assert_predicate HTTP::Response::Status.new(code).reason, :frozen?
    end
  end

  # ---------------------------------------------------------------------------
  # category methods
  # ---------------------------------------------------------------------------
  all_category_methods = %i[informational? success? redirect? client_error? server_error?]

  {
    100...200 => :informational?,
    200...300 => :success?,
    300...400 => :redirect?,
    400...500 => :client_error?,
    500...600 => :server_error?
  }.each do |range, positive_method|
    prefix = range.first / 100

    define_method(:"test_#{prefix}xx_codes_are_#{positive_method.to_s.chomp('?')}") do
      statuses = range.map { |code| HTTP::Response::Status.new(code) }

      assert(statuses.all?(&positive_method))
    end

    (all_category_methods - [positive_method]).each do |method|
      define_method(:"test_#{prefix}xx_codes_are_not_#{method.to_s.chomp('?')}") do
        statuses = range.map { |code| HTTP::Response::Status.new(code) }

        assert(statuses.none?(&method))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #to_sym
  # ---------------------------------------------------------------------------
  def test_to_sym_with_unknown_code_returns_nil
    assert_nil HTTP::Response::Status.new(1024).to_sym
  end

  HTTP::Response::Status::SYMBOLS.each do |code, symbol|
    define_method(:"test_to_sym_#{code}_returns_#{symbol}") do
      assert_equal symbol, HTTP::Response::Status.new(code).to_sym
    end
  end

  # ---------------------------------------------------------------------------
  # #inspect
  # ---------------------------------------------------------------------------
  def test_inspect_returns_quoted_code_and_reason_phrase
    status = HTTP::Response::Status.new(200)

    assert_equal "#<HTTP::Response::Status 200 OK>", status.inspect
  end

  # ---------------------------------------------------------------------------
  # ::SYMBOLS
  # ---------------------------------------------------------------------------
  def test_symbols_maps_200_to_ok
    assert_equal :ok, HTTP::Response::Status::SYMBOLS[200]
  end

  def test_symbols_maps_400_to_bad_request
    assert_equal :bad_request, HTTP::Response::Status::SYMBOLS[400]
  end

  # ---------------------------------------------------------------------------
  # symbol? predicate methods
  # ---------------------------------------------------------------------------
  HTTP::Response::Status::SYMBOLS.each do |code, symbol|
    define_method(:"test_#{symbol}_predicate_returns_true_when_code_is_#{code}") do
      assert HTTP::Response::Status.new(code).send(:"#{symbol}?")
    end

    define_method(:"test_#{symbol}_predicate_returns_false_when_code_is_higher_than_#{code}") do
      refute HTTP::Response::Status.new(code + 1).send(:"#{symbol}?")
    end

    define_method(:"test_#{symbol}_predicate_returns_false_when_code_is_lower_than_#{code}") do
      refute HTTP::Response::Status.new(code - 1).send(:"#{symbol}?")
    end
  end

  # ---------------------------------------------------------------------------
  # #to_s
  # ---------------------------------------------------------------------------
  def test_to_s_strips_trailing_whitespace_for_unknown_codes
    assert_equal "1024", HTTP::Response::Status.new(1024).to_s
  end

  # ---------------------------------------------------------------------------
  # #initialize error message
  # ---------------------------------------------------------------------------
  def test_initialize_includes_inspected_object_in_error_message
    obj = Object.new
    def obj.to_s = "custom"

    err = assert_raises(TypeError) { HTTP::Response::Status.new(obj) }
    assert_match(/#<Object:0x\h+>/, err.message)
    refute_includes err.message, "custom"
  end

  # ---------------------------------------------------------------------------
  # #to_i
  # ---------------------------------------------------------------------------
  def test_to_i_returns_the_integer_code
    assert_equal 200, HTTP::Response::Status.new(200).to_i
  end

  # ---------------------------------------------------------------------------
  # #to_int
  # ---------------------------------------------------------------------------
  def test_to_int_returns_the_integer_code
    assert_equal 200, HTTP::Response::Status.new(200).to_int
  end

  # ---------------------------------------------------------------------------
  # #<=>
  # ---------------------------------------------------------------------------
  def test_spaceship_compares_by_code
    assert_equal(-1, HTTP::Response::Status.new(200) <=> HTTP::Response::Status.new(404))
  end

  def test_spaceship_compares_with_integers
    assert_equal 0, HTTP::Response::Status.new(200) <=> 200
  end

  def test_spaceship_returns_nil_for_non_numeric
    assert_nil HTTP::Response::Status.new(200) <=> Object.new
  end

  def test_spaceship_compares_with_objects_that_respond_to_to_i_but_not_to_int
    assert_equal 1, HTTP::Response::Status.new(200) <=> "abc"
  end

  # ---------------------------------------------------------------------------
  # #==
  # ---------------------------------------------------------------------------
  def test_equal_to_another_status_with_same_code
    assert_equal HTTP::Response::Status.new(200), HTTP::Response::Status.new(200)
  end

  def test_not_equal_to_status_with_different_code
    refute_equal HTTP::Response::Status.new(200), HTTP::Response::Status.new(404)
  end

  # ---------------------------------------------------------------------------
  # #hash
  # ---------------------------------------------------------------------------
  def test_hash_is_same_for_equal_statuses
    assert_equal HTTP::Response::Status.new(200).hash, HTTP::Response::Status.new(200).hash
  end

  def test_hash_is_consistent_with_codes_hash
    assert_equal 200.hash, HTTP::Response::Status.new(200).hash
  end

  # ---------------------------------------------------------------------------
  # #deconstruct_keys
  # ---------------------------------------------------------------------------
  def test_deconstruct_keys_returns_all_keys_when_given_nil
    status = HTTP::Response::Status.new(200)

    assert_equal({ code: 200, reason: "OK" }, status.deconstruct_keys(nil))
  end

  def test_deconstruct_keys_returns_only_requested_keys
    status = HTTP::Response::Status.new(200)
    result = status.deconstruct_keys([:code])

    assert_equal({ code: 200 }, result)
  end

  def test_deconstruct_keys_excludes_unrequested_keys
    status = HTTP::Response::Status.new(200)

    refute_includes status.deconstruct_keys([:code]).keys, :reason
  end

  def test_deconstruct_keys_returns_empty_hash_for_empty_keys
    status = HTTP::Response::Status.new(200)

    assert_equal({}, status.deconstruct_keys([]))
  end

  def test_deconstruct_keys_returns_nil_reason_for_unknown_code
    unknown = HTTP::Response::Status.new(1024)

    assert_equal({ code: 1024, reason: nil }, unknown.deconstruct_keys(nil))
  end

  def test_deconstruct_keys_supports_pattern_matching_with_case_in
    status = HTTP::Response::Status.new(200)
    matched = case status
              in { code: 200..299 }
                true
              else
                false
              end

    assert matched
  end

  def test_deconstruct_keys_supports_pattern_matching_with_specific_code
    status = HTTP::Response::Status.new(200)
    matched = case status
              in { code: 200, reason: "OK" }
                true
              else
                false
              end

    assert matched
  end

  # ---------------------------------------------------------------------------
  # boundary conditions
  # ---------------------------------------------------------------------------
  def test_code_99_is_not_informational
    refute_predicate HTTP::Response::Status.new(99), :informational?
  end

  def test_code_600_is_not_server_error
    refute_predicate HTTP::Response::Status.new(600), :server_error?
  end

  # ---------------------------------------------------------------------------
  # .coerce
  # ---------------------------------------------------------------------------
  def test_coerce_with_string_coerces_reasons
    assert_equal HTTP::Response::Status.new(400), HTTP::Response::Status.coerce("Bad request")
  end

  def test_coerce_with_string_coerces_hyphenated_reasons
    assert_equal HTTP::Response::Status.new(207), HTTP::Response::Status.coerce("Multi-Status")
  end

  def test_coerce_with_string_coerces_reasons_with_multiple_words
    assert_equal HTTP::Response::Status.new(203), HTTP::Response::Status.coerce("Non-Authoritative Information")
  end

  def test_coerce_with_string_fails_when_reason_is_unknown
    assert_raises(HTTP::Error) { HTTP::Response::Status.coerce("foobar") }
  end

  def test_coerce_with_symbol_coerces_symbolized_reasons
    assert_equal HTTP::Response::Status.new(400), HTTP::Response::Status.coerce(:bad_request)
  end

  def test_coerce_with_symbol_fails_when_symbolized_reason_is_unknown
    assert_raises(HTTP::Error) { HTTP::Response::Status.coerce(:foobar) }
  end

  def test_coerce_with_numeric_coerces_as_fixnum_code
    assert_equal HTTP::Response::Status.new(200), HTTP::Response::Status.coerce(200.1)
  end

  def test_coerce_returns_a_status_instance
    result = HTTP::Response::Status.coerce(:ok)

    assert_instance_of HTTP::Response::Status, result
  end

  def test_coerce_fails_if_coercion_failed
    err = assert_raises(HTTP::Error) { HTTP::Response::Status.coerce(true) }
    assert_includes err.message, "TrueClass"
    assert_includes err.message, "true"
    assert_includes err.message, "HTTP::Response::Status"
  end

  def test_coerce_is_aliased_as_brackets
    status = HTTP::Response::Status[:ok]

    assert_equal 200, status.code
  end
end
