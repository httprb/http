# frozen_string_literal: true

require "test_helper"

class FormDataMultipartTest < Minitest::Test
  cover "HTTP::FormData::Multipart*"

  BOUNDARY_PATTERN = /-{21}[a-f0-9]{42}/
  CRLF = "\r\n"

  private

  def fixture_path
    @fixture_path ||= Pathname.new(__dir__).join("fixtures/the-http-gem.info").realpath
  end

  def file
    @file ||= HTTP::FormData::File.new(fixture_path)
  end

  def params
    { foo: :bar, baz: file }
  end

  def form_data
    @form_data ||= HTTP::FormData::Multipart.new(params)
  end

  def disposition(params)
    params = params.map { |k, v| "#{k}=#{v.inspect}" }.join("; ")
    "Content-Disposition: form-data; #{params}"
  end

  public

  # --- Multipart body generation ---

  def test_generates_multipart_data
    b = form_data.boundary
    expected = [
      "--#{b}#{CRLF}",
      "#{disposition 'name' => 'foo'}#{CRLF}",
      "#{CRLF}bar#{CRLF}",
      "--#{b}#{CRLF}",
      "#{disposition 'name' => 'baz', 'filename' => file.filename}#{CRLF}",
      "Content-Type: #{file.content_type}#{CRLF}",
      "#{CRLF}#{file}#{CRLF}",
      "--#{b}--#{CRLF}"
    ].join

    assert_equal expected, form_data.to_s
  end

  def test_user_defined_boundary
    fd = HTTP::FormData::Multipart.new(params, boundary: "my-boundary")
    expected = [
      "--my-boundary#{CRLF}",
      "#{disposition 'name' => 'foo'}#{CRLF}",
      "#{CRLF}bar#{CRLF}",
      "--my-boundary#{CRLF}",
      "#{disposition 'name' => 'baz', 'filename' => file.filename}#{CRLF}",
      "Content-Type: #{file.content_type}#{CRLF}",
      "#{CRLF}#{file}#{CRLF}",
      "--my-boundary--#{CRLF}"
    ].join

    assert_equal expected, fd.to_s
  end

  def test_part_without_filename
    part = HTTP::FormData::Part.new("s", content_type: "mime/type")
    fd = HTTP::FormData::Multipart.new({ foo: part })
    b = fd.content_type[/(#{BOUNDARY_PATTERN})$/o, 1]

    expected = [
      "--#{b}#{CRLF}",
      "#{disposition 'name' => 'foo'}#{CRLF}",
      "Content-Type: #{part.content_type}#{CRLF}",
      "#{CRLF}s#{CRLF}",
      "--#{b}--#{CRLF}"
    ].join

    assert_equal expected, fd.to_s
  end

  def test_part_without_content_type
    part = HTTP::FormData::Part.new("s")
    fd = HTTP::FormData::Multipart.new({ foo: part })
    b = fd.content_type[/(#{BOUNDARY_PATTERN})$/o, 1]

    expected = [
      "--#{b}#{CRLF}",
      "#{disposition 'name' => 'foo'}#{CRLF}",
      "#{CRLF}s#{CRLF}",
      "--#{b}--#{CRLF}"
    ].join

    assert_equal expected, fd.to_s
  end

  def test_supports_enumerable_of_pairs
    enum = Enumerator.new { |y| y << %i[foo bar] << %i[foo baz] }
    fd = HTTP::FormData::Multipart.new(enum)
    b = fd.boundary

    expected = [
      "--#{b}#{CRLF}",
      "#{disposition 'name' => 'foo'}#{CRLF}",
      "#{CRLF}bar#{CRLF}",
      "--#{b}#{CRLF}",
      "#{disposition 'name' => 'foo'}#{CRLF}",
      "#{CRLF}baz#{CRLF}",
      "--#{b}--#{CRLF}"
    ].join

    assert_equal expected, fd.to_s
  end

  def test_array_of_pairs_with_duplicate_names
    data = [
      ["metadata", %(filename="first.txt")],
      ["file", HTTP::FormData::File.new(StringIO.new("uno"), content_type: "plain/text", filename: "abc")],
      ["metadata", %(filename="second.txt")],
      ["file", HTTP::FormData::File.new(StringIO.new("dos"), content_type: "plain/text", filename: "xyz")],
      ["metadata", %w[question=why question=not]]
    ]
    fd = HTTP::FormData::Multipart.new(data)
    b = fd.boundary

    expected = [
      %(--#{b}\r\n),
      %(Content-Disposition: form-data; name="metadata"\r\n),
      %(\r\nfilename="first.txt"\r\n),
      %(--#{b}\r\n),
      %(Content-Disposition: form-data; name="file"; filename="abc"\r\n),
      %(Content-Type: plain/text\r\n),
      %(\r\nuno\r\n),
      %(--#{b}\r\n),
      %(Content-Disposition: form-data; name="metadata"\r\n),
      %(\r\nfilename="second.txt"\r\n),
      %(--#{b}\r\n),
      %(Content-Disposition: form-data; name="file"; filename="xyz"\r\n),
      %(Content-Type: plain/text\r\n),
      %(\r\ndos\r\n),
      %(--#{b}\r\n),
      %(Content-Disposition: form-data; name="metadata"\r\n),
      %(\r\nquestion=why\r\n),
      %(--#{b}\r\n),
      %(Content-Disposition: form-data; name="metadata"\r\n),
      %(\r\nquestion=not\r\n),
      %(--#{b}--\r\n)
    ].join

    assert_equal expected, fd.to_s
  end

  # --- size / read / rewind ---

  def test_size_returns_bytesize
    assert_equal form_data.to_s.bytesize, form_data.size
  end

  def test_read_returns_multipart_data
    assert_equal form_data.to_s, form_data.read
  end

  def test_rewind
    form_data.read
    form_data.rewind

    assert_equal form_data.to_s, form_data.read
  end

  def test_content_length
    assert_equal form_data.to_s.bytesize, form_data.content_length
  end

  def test_to_s_rewinds_content
    content = form_data.read

    assert_equal content, form_data.to_s
    assert_equal content, form_data.read
  end

  # --- Content type ---

  def test_content_type_matches_pattern
    assert_match(%r{^multipart/form-data; boundary=#{BOUNDARY_PATTERN}$}o, form_data.content_type)
  end

  def test_content_type_with_user_defined_boundary
    fd = HTTP::FormData::Multipart.new(params, boundary: "my-boundary")

    assert_equal "multipart/form-data; boundary=my-boundary", fd.content_type
  end

  def test_content_type_with_custom_type
    fd = HTTP::FormData::Multipart.new(params, boundary: "b", content_type: "multipart/related")

    assert_equal "multipart/related; boundary=b", fd.content_type
  end

  def test_content_type_with_multipart_mixed
    fd = HTTP::FormData::Multipart.new(params, boundary: "b", content_type: "multipart/mixed")

    assert_equal "multipart/mixed; boundary=b", fd.content_type
  end

  def test_content_type_default_is_form_data
    assert_equal "multipart/form-data", HTTP::FormData::Multipart::DEFAULT_CONTENT_TYPE
  end

  def test_content_type_converts_to_string
    fd = HTTP::FormData::Multipart.new(params, boundary: "b", content_type: :"multipart/related")

    assert_equal "multipart/related; boundary=b", fd.content_type
    assert_instance_of String, fd.content_type
  end

  # --- Boundary ---

  def test_boundary_matches_pattern
    assert_match(BOUNDARY_PATTERN, form_data.boundary)
  end

  def test_boundary_with_user_defined_value
    fd = HTTP::FormData::Multipart.new(params, boundary: "my-boundary")

    assert_equal "my-boundary", fd.boundary
  end

  def test_boundary_is_frozen_string
    assert_predicate form_data.boundary, :frozen?
    assert_instance_of String, form_data.boundary
  end

  def test_boundary_with_symbol_value
    fd = HTTP::FormData::Multipart.new({ foo: "bar" }, boundary: :"my-sym-boundary")

    assert_equal "my-sym-boundary", fd.boundary
    assert_instance_of String, fd.boundary
  end

  def test_generate_boundary
    assert_match(BOUNDARY_PATTERN, HTTP::FormData::Multipart.generate_boundary)
  end

  # --- Param ---

  def test_parts_with_nil_data
    form = HTTP::FormData::Multipart.new(nil, boundary: "test-boundary")

    assert_equal "--test-boundary--\r\n", form.to_s
  end

  def test_param_converts_name_to_string
    part = HTTP::FormData::Part.new("val")
    body = HTTP::FormData::Multipart.new({ 123 => part }, boundary: "b").to_s

    assert_includes body, 'name="123"'
  end

  def test_param_wraps_non_part_value
    body = HTTP::FormData::Multipart.new({ foo: "raw_string" }, boundary: "b").to_s

    assert_includes body, "raw_string"
    refute_includes body, "Content-Type:"
  end

  def test_param_uses_part_directly
    part = HTTP::FormData::Part.new("part_body", content_type: "text/plain")
    body = HTTP::FormData::Multipart.new({ foo: part }, boundary: "b").to_s

    assert_includes body, "part_body"
    assert_includes body, "Content-Type: text/plain"
  end

  def test_param_header_contains_content_disposition
    body = HTTP::FormData::Multipart.new({ myfield: "val" }, boundary: "b").to_s

    assert_includes body, "Content-Disposition: form-data; name=\"myfield\""
  end

  def test_param_includes_content_type_when_present
    part = HTTP::FormData::Part.new("val", content_type: "application/json")
    body = HTTP::FormData::Multipart.new({ f: part }, boundary: "b").to_s

    assert_includes body, "Content-Type: application/json\r\n"
  end

  def test_param_excludes_content_type_when_nil
    part = HTTP::FormData::Part.new("val")
    body = HTTP::FormData::Multipart.new({ f: part }, boundary: "b").to_s

    refute_includes body, "Content-Type:"
  end

  def test_param_footer_is_crlf
    body = HTTP::FormData::Multipart.new({ f: "v" }, boundary: "b").to_s

    assert_includes body, "v\r\n--b--"
  end
end
