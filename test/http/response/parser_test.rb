# frozen_string_literal: true

require "test_helper"

class HTTPResponseParserTest < Minitest::Test
  cover "HTTP::Response::Parser*"

  RAW_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nContent-Type: application/json\r\n" \
                 "MyHeader: val\r\nEmptyHeader: \r\n\r\n{}"
  EXPECTED_HEADERS = {
    "Content-Length" => "2",
    "Content-Type"   => "application/json",
    "MyHeader"       => "val",
    "EmptyHeader"    => ""
  }.freeze
  EXPECTED_BODY = "{}"

  # ---------------------------------------------------------------------------
  # whole response in one part
  # ---------------------------------------------------------------------------
  def test_whole_response_parses_headers
    parser = HTTP::Response::Parser.new
    parser.add(RAW_RESPONSE)

    assert_equal EXPECTED_HEADERS, parser.headers.to_h
  end

  def test_whole_response_parses_body
    parser = HTTP::Response::Parser.new
    parser.add(RAW_RESPONSE)

    assert_equal EXPECTED_BODY, parser.read(EXPECTED_BODY.size)
  end

  # ---------------------------------------------------------------------------
  # response in many parts
  # ---------------------------------------------------------------------------
  def test_many_parts_parses_headers
    parser = HTTP::Response::Parser.new
    RAW_RESPONSE.chars.each { |part| parser.add(part) }

    assert_equal EXPECTED_HEADERS, parser.headers.to_h
  end

  def test_many_parts_parses_body
    parser = HTTP::Response::Parser.new
    RAW_RESPONSE.chars.each { |part| parser.add(part) }

    assert_equal EXPECTED_BODY, parser.read(EXPECTED_BODY.size)
  end

  # ---------------------------------------------------------------------------
  # #add with invalid data
  # ---------------------------------------------------------------------------
  def test_add_raises_io_error_on_invalid_http_data
    parser = HTTP::Response::Parser.new

    assert_raises(IOError) { parser.add("NOT HTTP AT ALL\r\n\r\n") }
  end

  # ---------------------------------------------------------------------------
  # #read with chunk larger than requested size
  # ---------------------------------------------------------------------------
  def test_read_returns_only_requested_bytes_and_retains_rest
    raw = "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n0123456789"
    parser = HTTP::Response::Parser.new
    parser.add(raw)

    chunk = parser.read(4)

    assert_equal "0123", chunk
    chunk = parser.read(6)

    assert_equal "456789", chunk
  end

  # ---------------------------------------------------------------------------
  # 100 Continue response
  # ---------------------------------------------------------------------------
  def test_100_continue_in_one_part_skips_to_next_non_info_response
    raw = "HTTP/1.1 100 Continue\r\n\r\n" \
          "HTTP/1.1 200 OK\r\n" \
          "Content-Length: 12\r\n\r\n" \
          "Hello World!"
    parser = HTTP::Response::Parser.new
    parser.add(raw)

    assert_equal 200, parser.status_code
    assert_equal({ "Content-Length" => "12" }, parser.headers)
    assert_equal "Hello World!", parser.read(12)
  end

  def test_100_continue_in_many_parts_skips_to_next_non_info_response
    raw = "HTTP/1.1 100 Continue\r\n\r\n" \
          "HTTP/1.1 200 OK\r\n" \
          "Content-Length: 12\r\n\r\n" \
          "Hello World!"
    parser = HTTP::Response::Parser.new
    raw.chars.each { |part| parser.add(part) }

    assert_equal 200, parser.status_code
    assert_equal({ "Content-Length" => "12" }, parser.headers)
    assert_equal "Hello World!", parser.read(12)
  end
end
