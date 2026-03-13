# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::AutoDeflate do
  cover "HTTP::Features::AutoDeflate*"
  let(:subject_under_test) { HTTP::Features::AutoDeflate.new }

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

  it "raises error for wrong type" do
    err = assert_raises(HTTP::Error) { HTTP::Features::AutoDeflate.new(method: :wrong) }
    assert_equal "Only gzip and deflate methods are supported", err.message
  end

  it "accepts gzip method" do
    assert_equal "gzip", HTTP::Features::AutoDeflate.new(method: :gzip).method
  end

  it "accepts deflate method" do
    assert_equal "deflate", HTTP::Features::AutoDeflate.new(method: :deflate).method
  end

  it "accepts string as method" do
    assert_equal "gzip", HTTP::Features::AutoDeflate.new(method: "gzip").method
  end

  it "uses gzip by default" do
    assert_equal "gzip", subject_under_test.method
  end

  it "is a Feature" do
    assert_kind_of HTTP::Feature, subject_under_test
  end

  describe "#wrap_request" do
    let(:custom_normalizer) { ->(uri) { HTTP::URI::NORMALIZER.call(uri) } }

    let(:request) do
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

    context "when method is nil" do
      before { subject_under_test.instance_variable_set(:@method, nil) }

      it "returns the original request" do
        assert_same request, subject_under_test.wrap_request(request)
      end
    end

    context "when body is empty" do
      let(:empty_request) do
        HTTP::Request.new(
          verb: :post,
          uri:  "http://example.com/"
        )
      end

      it "returns the original request" do
        assert_same empty_request, subject_under_test.wrap_request(empty_request)
      end
    end

    context "with gzip method and non-empty body" do
      let(:result) { subject_under_test.wrap_request(request) }

      it "returns a new request (not the original)" do
        refute_same request, result
      end

      it "returns an HTTP::Request" do
        assert_instance_of HTTP::Request, result
      end

      it "sets Content-Encoding header to the method" do
        assert_equal "gzip", result.headers["Content-Encoding"]
      end

      it "removes Content-Length header" do
        refute_includes result.headers.to_h.keys.map(&:downcase), "content-length"
      end

      it "preserves the verb" do
        assert_equal :post, result.verb
      end

      it "preserves the uri" do
        assert_equal request.uri, result.uri
      end

      it "preserves the version" do
        assert_equal request.version, result.version
      end

      it "wraps the body in a GzippedBody" do
        assert_instance_of HTTP::Features::AutoDeflate::GzippedBody, result.body
      end

      it "compresses the original request body data" do
        compressed = result.body.each.to_a.join
        decompressed = Zlib::GzipReader.new(StringIO.new(compressed)).read

        assert_equal "data", decompressed
      end

      it "preserves the proxy" do
        assert_equal request.proxy, result.proxy
      end

      it "preserves the uri_normalizer" do
        assert_same custom_normalizer, result.uri_normalizer
      end
    end

    context "with deflate method and non-empty body" do
      let(:subject_under_test) { HTTP::Features::AutoDeflate.new(method: :deflate) }
      let(:result) { subject_under_test.wrap_request(request) }

      it "sets Content-Encoding to deflate" do
        assert_equal "deflate", result.headers["Content-Encoding"]
      end

      it "wraps the body in a DeflatedBody" do
        assert_instance_of HTTP::Features::AutoDeflate::DeflatedBody, result.body
      end
    end
  end

  describe "#deflated_body" do
    let(:body)          { %w[bees cows] }
    let(:deflated_body) { subject_under_test.deflated_body(body) }

    context "when method is unknown" do
      before { subject_under_test.instance_variable_set(:@method, "unknown") }

      it "returns nil" do
        assert_nil subject_under_test.deflated_body(body)
      end
    end

    context "when method is gzip" do
      let(:subject_under_test) { HTTP::Features::AutoDeflate.new(method: :gzip) }

      it "returns object which yields gzipped content of the given body" do
        result = deflated_body.each.to_a.join
        decompressed = Zlib::GzipReader.new(StringIO.new(result)).read

        assert_equal "beescows", decompressed
      end

      it "caches compressed content when size is called" do
        size = deflated_body.size
        result = deflated_body.each.to_a.join
        decompressed = Zlib::GzipReader.new(StringIO.new(result)).read

        assert_equal result.bytesize, size
        assert_equal "beescows", decompressed
      end

      it "reuses cached compression on subsequent size calls" do
        single_use_body = single_use_source(%w[bees cows])
        gzipped = HTTP::Features::AutoDeflate::GzippedBody.new(single_use_body)
        first_size = gzipped.size

        assert_equal first_size, gzipped.size
      end
    end

    context "when method is deflate" do
      let(:subject_under_test) { HTTP::Features::AutoDeflate.new(method: :deflate) }

      it "returns object which yields deflated content of the given body" do
        deflated = Zlib::Deflate.deflate("beescows")

        assert_equal deflated, deflated_body.each.to_a.join
      end

      it "caches compressed content when size is called" do
        deflated = Zlib::Deflate.deflate("beescows")

        assert_equal deflated.bytesize, deflated_body.size
        assert_equal deflated, deflated_body.each.to_a.join
      end
    end
  end

  describe HTTP::Features::AutoDeflate::CompressedBody do
    let(:inner_body) { %w[hello world] }

    describe "#initialize" do
      it "sets source to nil via super" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)

        assert_nil body.source
      end
    end

    describe "#each" do
      it "returns an Enumerator when no block is given" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
        enum = body.each

        assert_instance_of Enumerator, enum
      end

      it "returns self when block is given" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
        result = body.each { |_chunk| nil }

        assert_same body, result
      end

      it "yields compressed data via compress when not cached" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
        chunks = body.each.map { |chunk| chunk }

        refute_empty chunks
      end

      it "reads from cache when size was called first on single-use body" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(single_use_source(%w[hello world]))
        expected_size = body.size

        chunks = body.each.map { |chunk| chunk }
        actual = chunks.join

        assert_equal expected_size, actual.bytesize

        decompressed = Zlib::GzipReader.new(StringIO.new(actual)).read

        assert_equal "helloworld", decompressed
      end

      it "cleans up tempfile after reading cached data" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
        body.size

        path = body.instance_variable_get(:@compressed).path
        body.each { |_| nil }

        refute_path_exists path
      end

      it "can be enumerated multiple times via to_enum" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
        first_result = body.each.to_a.join
        # After each consumes via compress, we need a fresh body to test enum
        body2 = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)

        assert_equal first_result, body2.each.to_a.join
      end
    end
  end

  describe HTTP::Features::AutoDeflate::GzippedBody do
    let(:inner_body) { %w[hello world] }

    describe "#compress" do
      it "produces valid gzip data" do
        body = HTTP::Features::AutoDeflate::GzippedBody.new(inner_body)
        compressed = body.each.to_a.join
        decompressed = Zlib::GzipReader.new(StringIO.new(compressed)).read

        assert_equal "helloworld", decompressed
      end
    end
  end

  describe HTTP::Features::AutoDeflate::DeflatedBody do
    let(:inner_body) { %w[hello world] }

    describe "#compress" do
      it "produces valid deflate data" do
        body = HTTP::Features::AutoDeflate::DeflatedBody.new(inner_body)
        compressed = body.each.to_a.join
        decompressed = Zlib::Inflate.inflate(compressed)

        assert_equal "helloworld", decompressed
      end
    end
  end
end
