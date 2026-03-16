# frozen_string_literal: true

require "test_helper"

class HTTPFeaturesAutoDeflateTest < Minitest::Test
  cover "HTTP::Features::AutoDeflate*"

  # Returns a body source that can only be iterated once; second iteration yields nothing.
  def single_use_source(chunks)
    consumed = false
    fake(each: proc { |&block|
      unless consumed
        consumed = true
        chunks.each { |chunk| block.call(chunk) }
      end
    })
  end

  def subject_under_test
    @subject_under_test ||= HTTP::Features::AutoDeflate.new
  end

  def test_raises_error_for_wrong_type
    err = assert_raises(HTTP::Error) { HTTP::Features::AutoDeflate.new(method: :wrong) }
    assert_equal "Only gzip and deflate methods are supported", err.message
  end

  def test_accepts_gzip_method
    assert_equal "gzip", HTTP::Features::AutoDeflate.new(method: :gzip).method
  end

  def test_accepts_deflate_method
    assert_equal "deflate", HTTP::Features::AutoDeflate.new(method: :deflate).method
  end

  def test_accepts_string_as_method
    assert_equal "gzip", HTTP::Features::AutoDeflate.new(method: "gzip").method
  end

  def test_uses_gzip_by_default
    assert_equal "gzip", subject_under_test.method
  end

  def test_is_a_feature
    assert_kind_of HTTP::Feature, subject_under_test
  end

  # -- #wrap_request --

  def build_request
    custom_normalizer = ->(uri) { HTTP::URI::NORMALIZER.call(uri) }
    HTTP::Request.new(
      verb:           :post,
      uri:            "http://example.com/",
      headers:        { "Content-Length" => "4" },
      body:           "data",
      version:        "2.0",
      proxy:          { proxy_host: "proxy.example.com" },
      uri_normalizer: custom_normalizer
    )
  end

  def test_wrap_request_when_method_is_nil_returns_the_original_request
    sut = HTTP::Features::AutoDeflate.new
    sut.instance_variable_set(:@method, nil)
    request = build_request

    assert_same request, sut.wrap_request(request)
  end

  def test_wrap_request_when_body_is_empty_returns_the_original_request
    empty_request = HTTP::Request.new(
      verb: :post,
      uri:  "http://example.com/"
    )

    assert_same empty_request, subject_under_test.wrap_request(empty_request)
  end

  def test_wrap_request_with_gzip_returns_a_new_request
    request = build_request
    result = subject_under_test.wrap_request(request)

    refute_same request, result
  end

  def test_wrap_request_with_gzip_returns_an_http_request
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_instance_of HTTP::Request, result
  end

  def test_wrap_request_with_gzip_sets_content_encoding_header
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_equal "gzip", result.headers["Content-Encoding"]
  end

  def test_wrap_request_with_gzip_removes_content_length_header
    request = build_request
    result = subject_under_test.wrap_request(request)

    refute_includes result.headers.to_h.keys.map(&:downcase), "content-length"
  end

  def test_wrap_request_with_gzip_preserves_the_verb
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_equal :post, result.verb
  end

  def test_wrap_request_with_gzip_preserves_the_uri
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_equal request.uri, result.uri
  end

  def test_wrap_request_with_gzip_preserves_the_version
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_equal request.version, result.version
  end

  def test_wrap_request_with_gzip_wraps_the_body_in_a_gzipped_body
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_instance_of HTTP::Features::AutoDeflate::GzippedBody, result.body
  end

  def test_wrap_request_with_gzip_compresses_the_original_request_body_data
    request = build_request
    result = subject_under_test.wrap_request(request)
    compressed = result.body.each.to_a.join
    decompressed = Zlib::GzipReader.new(StringIO.new(compressed)).read

    assert_equal "data", decompressed
  end

  def test_wrap_request_with_gzip_preserves_the_proxy
    request = build_request
    result = subject_under_test.wrap_request(request)

    assert_equal request.proxy, result.proxy
  end

  def test_wrap_request_with_gzip_preserves_the_uri_normalizer
    custom_normalizer = ->(uri) { HTTP::URI::NORMALIZER.call(uri) }
    request = HTTP::Request.new(
      verb:           :post,
      uri:            "http://example.com/",
      headers:        { "Content-Length" => "4" },
      body:           "data",
      version:        "2.0",
      proxy:          { proxy_host: "proxy.example.com" },
      uri_normalizer: custom_normalizer
    )
    result = subject_under_test.wrap_request(request)

    assert_same custom_normalizer, result.uri_normalizer
  end

  def test_wrap_request_with_deflate_sets_content_encoding_to_deflate
    sut = HTTP::Features::AutoDeflate.new(method: :deflate)
    request = build_request
    result = sut.wrap_request(request)

    assert_equal "deflate", result.headers["Content-Encoding"]
  end

  def test_wrap_request_with_deflate_wraps_the_body_in_a_deflated_body
    sut = HTTP::Features::AutoDeflate.new(method: :deflate)
    request = build_request
    result = sut.wrap_request(request)

    assert_instance_of HTTP::Features::AutoDeflate::DeflatedBody, result.body
  end

  # -- #deflated_body --

  def test_deflated_body_when_method_is_unknown_returns_nil
    sut = HTTP::Features::AutoDeflate.new
    sut.instance_variable_set(:@method, "unknown")

    assert_nil sut.deflated_body(%w[bees cows])
  end

  def test_deflated_body_when_method_is_gzip_yields_gzipped_content
    sut = HTTP::Features::AutoDeflate.new(method: :gzip)
    deflated_body = sut.deflated_body(%w[bees cows])
    result = deflated_body.each.to_a.join
    decompressed = Zlib::GzipReader.new(StringIO.new(result)).read

    assert_equal "beescows", decompressed
  end

  def test_deflated_body_when_method_is_gzip_caches_compressed_content_when_size_is_called
    sut = HTTP::Features::AutoDeflate.new(method: :gzip)
    deflated_body = sut.deflated_body(%w[bees cows])
    size = deflated_body.size
    result = deflated_body.each.to_a.join
    decompressed = Zlib::GzipReader.new(StringIO.new(result)).read

    assert_equal result.bytesize, size
    assert_equal "beescows", decompressed
  end

  def test_deflated_body_when_method_is_gzip_reuses_cached_compression_on_subsequent_size_calls
    single_use_body = single_use_source(%w[bees cows])
    gzipped = HTTP::Features::AutoDeflate::GzippedBody.new(single_use_body)
    first_size = gzipped.size

    assert_equal first_size, gzipped.size
  end

  def test_deflated_body_when_method_is_deflate_yields_deflated_content
    sut = HTTP::Features::AutoDeflate.new(method: :deflate)
    deflated_body = sut.deflated_body(%w[bees cows])
    deflated = Zlib::Deflate.deflate("beescows")

    assert_equal deflated, deflated_body.each.to_a.join
  end

  def test_deflated_body_when_method_is_deflate_caches_compressed_content_when_size_is_called
    sut = HTTP::Features::AutoDeflate.new(method: :deflate)
    deflated_body = sut.deflated_body(%w[bees cows])
    deflated = Zlib::Deflate.deflate("beescows")

    assert_equal deflated.bytesize, deflated_body.size
    assert_equal deflated, deflated_body.each.to_a.join
  end

  # -- CompressedBody --

  def test_compressed_body_initialize_sets_source_to_nil_via_super
    body = HTTP::Features::AutoDeflate::GzippedBody.new(%w[hello world])

    assert_nil body.source
  end

  def test_compressed_body_each_returns_an_enumerator_when_no_block_is_given
    body = HTTP::Features::AutoDeflate::GzippedBody.new(%w[hello world])
    enum = body.each

    assert_instance_of Enumerator, enum
  end

  def test_compressed_body_each_returns_self_when_block_is_given
    body = HTTP::Features::AutoDeflate::GzippedBody.new(%w[hello world])
    result = body.each { |_chunk| nil }

    assert_same body, result
  end

  def test_compressed_body_each_yields_compressed_data_via_compress_when_not_cached
    body = HTTP::Features::AutoDeflate::GzippedBody.new(%w[hello world])
    chunks = body.each.map { |chunk| chunk }

    refute_empty chunks
  end

  def test_compressed_body_each_reads_from_cache_when_size_was_called_first_on_single_use_body
    body = HTTP::Features::AutoDeflate::GzippedBody.new(single_use_source(%w[hello world]))
    expected_size = body.size
    chunks = body.each.map { |chunk| chunk }
    actual = chunks.join

    assert_equal expected_size, actual.bytesize
    decompressed = Zlib::GzipReader.new(StringIO.new(actual)).read

    assert_equal "helloworld", decompressed
  end

  def test_compressed_body_each_cleans_up_tempfile_after_reading_cached_data
    body = HTTP::Features::AutoDeflate::GzippedBody.new(%w[hello world])
    body.size
    path = body.instance_variable_get(:@compressed).path
    body.each { |_| nil }

    refute_path_exists path
  end

  def test_compressed_body_each_can_be_enumerated_multiple_times_via_to_enum
    inner_body = %w[hello world]
    body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
    first_result = body.each.to_a.join
    # After each consumes via compress, we need a fresh body to test enum
    body2 = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)

    assert_equal first_result, body2.each.to_a.join
  end

  # -- GzippedBody --

  def test_gzipped_body_compress_produces_valid_gzip_data
    body = HTTP::Features::AutoDeflate::GzippedBody.new(%w[hello world])
    compressed = body.each.to_a.join
    decompressed = Zlib::GzipReader.new(StringIO.new(compressed)).read

    assert_equal "helloworld", decompressed
  end

  # -- DeflatedBody --

  def test_deflated_body_compress_produces_valid_deflate_data
    body = HTTP::Features::AutoDeflate::DeflatedBody.new(%w[hello world])
    compressed = body.each.to_a.join
    decompressed = Zlib::Inflate.inflate(compressed)

    assert_equal "helloworld", decompressed
  end
end
