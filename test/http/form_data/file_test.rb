# frozen_string_literal: true

require "test_helper"

class FormDataFileTest < Minitest::Test
  cover "HTTP::FormData::File*"

  private

  def fixture_path
    @fixture_path ||= Pathname.new(__dir__).join("fixtures/the-http-gem.info").realpath
  end

  def fixture_content
    @fixture_content ||= fixture_path.read(mode: "rb")
  end

  # Yields [form_file, label, expected_content] for each IO source type.
  # Handles closing File IOs in an ensure block.
  def each_source
    yield HTTP::FormData::File.new(fixture_path.to_s), "string_path", fixture_content
    yield HTTP::FormData::File.new(fixture_path), "pathname", fixture_content

    file = fixture_path.open("rb")
    begin
      yield HTTP::FormData::File.new(file), "file", fixture_content
    ensure
      file.close
    end

    yield HTTP::FormData::File.new(StringIO.new("привет мир!")), "string_io", "привет мир!"
  end

  public

  # --- Core Readable behavior across IO sources ---

  def test_size
    each_source do |form_file, label, content|
      assert_equal content.bytesize, form_file.size, "size failed for #{label}"
    end
  end

  def test_to_s
    each_source do |form_file, label, content|
      assert_equal content, form_file.to_s, "to_s failed for #{label}"
    end
  end

  def test_to_s_rewinds_content
    each_source do |form_file, label, _content|
      content = form_file.read

      assert_equal content, form_file.to_s, "to_s rewind failed for #{label}"
      assert_equal content, form_file.read, "read after to_s failed for #{label}"
    end
  end

  def test_read
    each_source do |form_file, label, content|
      assert_equal content, form_file.read, "read failed for #{label}"
    end
  end

  def test_rewind
    each_source do |form_file, label, _content|
      content = form_file.read
      form_file.rewind

      assert_equal content, form_file.read, "rewind failed for #{label}"
    end
  end

  # --- Filename detection ---

  def test_filename_with_string_path
    assert_equal "the-http-gem.info", HTTP::FormData::File.new(fixture_path.to_s).filename
  end

  def test_filename_with_string_path_and_option
    assert_equal "foobar.txt", HTTP::FormData::File.new(fixture_path.to_s, filename: "foobar.txt").filename
  end

  def test_filename_with_pathname
    assert_equal "the-http-gem.info", HTTP::FormData::File.new(fixture_path).filename
  end

  def test_filename_with_pathname_and_option
    assert_equal "foobar.txt", HTTP::FormData::File.new(fixture_path, filename: "foobar.txt").filename
  end

  def test_filename_with_file
    file = fixture_path.open

    assert_equal "the-http-gem.info", HTTP::FormData::File.new(file).filename
  ensure
    file.close
  end

  def test_filename_with_file_and_option
    file = fixture_path.open

    assert_equal "foobar.txt", HTTP::FormData::File.new(file, filename: "foobar.txt").filename
  ensure
    file.close
  end

  def test_filename_with_io
    io = StringIO.new

    assert_equal "stream-#{io.object_id}", HTTP::FormData::File.new(io).filename
  end

  def test_filename_with_io_and_option
    assert_equal "foobar.txt", HTTP::FormData::File.new(StringIO.new, filename: "foobar.txt").filename
  end

  # Kill: ::File.basename(io.path) replaced with ::File.basename(io)
  def test_filename_for_io_with_path_method
    io = StringIO.new("data")
    io.define_singleton_method(:path) { "/some/dir/custom.txt" }

    assert_equal "custom.txt", HTTP::FormData::File.new(io).filename
  end

  def test_filename_for_io_without_path
    io = StringIO.new("data")
    form_file = HTTP::FormData::File.new(io)

    assert_equal "stream-#{io.object_id}", form_file.filename
    assert_match(/\Astream-\d+\z/, form_file.filename)
  end

  # --- Content type ---

  def test_content_type_default
    assert_equal HTTP::FormData::File::DEFAULT_MIME, HTTP::FormData::File.new(StringIO.new).content_type
  end

  def test_content_type_with_option
    assert_equal "application/json",
                 HTTP::FormData::File.new(StringIO.new, content_type: "application/json").content_type
  end

  def test_content_type_converts_to_string
    form_file = HTTP::FormData::File.new(StringIO.new("data"), content_type: :json)

    assert_equal "json", form_file.content_type
    assert_instance_of String, form_file.content_type
  end

  # --- make_io ---

  def test_make_io_with_string_subclass
    assert_equal fixture_content, HTTP::FormData::File.new(Class.new(String).new(fixture_path.to_s)).to_s
  end

  def test_make_io_with_pathname_subclass
    assert_equal fixture_content, HTTP::FormData::File.new(Class.new(Pathname).new(fixture_path.to_s)).to_s
  end

  def test_string_path_opens_in_binmode
    assert_equal Encoding::ASCII_8BIT, HTTP::FormData::File.new(fixture_path.to_s).read.encoding
  end

  def test_pathname_opens_in_binmode
    assert_equal Encoding::ASCII_8BIT, HTTP::FormData::File.new(fixture_path).read.encoding
  end

  # --- initialize edge cases ---

  def test_initialize_with_nil_opts
    assert_equal "application/octet-stream", HTTP::FormData::File.new(StringIO.new("data"), nil).content_type
  end

  # --- Readable#read with length/outbuf ---

  def test_read_with_length
    assert_equal "hello", HTTP::FormData::File.new(StringIO.new("hello world")).read(5)
  end

  def test_read_with_nil_length
    assert_equal "hello world", HTTP::FormData::File.new(StringIO.new("hello world")).read(nil)
  end

  def test_read_with_length_and_outbuf
    form_file = HTTP::FormData::File.new(StringIO.new("hello world"))
    outbuf = +""
    result = form_file.read(5, outbuf)

    assert_equal "hello", result
    assert_equal "hello", outbuf
  end

  def test_read_after_eof_returns_nil_with_length
    form_file = HTTP::FormData::File.new(StringIO.new("hi"))
    form_file.read

    assert_nil form_file.read(1)
  end

  def test_read_after_eof_returns_empty_string_without_length
    form_file = HTTP::FormData::File.new(StringIO.new("hi"))
    form_file.read

    assert_equal "", form_file.read
  end

  # --- File#close ---

  def test_close_with_string_path_closes_io
    form_file = HTTP::FormData::File.new(fixture_path.to_s)
    form_file.read
    form_file.close

    assert_raises(IOError) { form_file.read }
  end

  def test_close_with_pathname_closes_io
    form_file = HTTP::FormData::File.new(fixture_path)
    form_file.read
    form_file.close

    assert_raises(IOError) { form_file.read }
  end

  def test_close_with_io_does_not_close
    io = StringIO.new("hello")
    HTTP::FormData::File.new(io).close

    assert_equal "hello", io.read
  end

  def test_close_is_idempotent
    form_file = HTTP::FormData::File.new(fixture_path.to_s)
    form_file.close
    form_file.close
  end

  def test_close_with_string_subclass_closes_io
    form_file = HTTP::FormData::File.new(Class.new(String).new(fixture_path.to_s))
    form_file.read
    form_file.close

    assert_raises(IOError) { form_file.read }
  end

  def test_close_with_pathname_subclass_closes_io
    form_file = HTTP::FormData::File.new(Class.new(Pathname).new(fixture_path.to_s))
    form_file.read
    form_file.close

    assert_raises(IOError) { form_file.read }
  end
end
