# frozen_string_literal: true

require "test_helper"

describe HTTP::Features::AutoDeflate do
  let(:subject_under_test) { HTTP::Features::AutoDeflate.new }

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

  describe "#wrap_request" do
    let(:request) do
      HTTP::Request.new(
        verb: :post,
        uri:  "http://example.com/",
        body: "data"
      )
    end

    context "when method is nil" do
      before { subject_under_test.instance_variable_set(:@method, nil) }

      it "returns the original request" do
        assert_same request, subject_under_test.wrap_request(request)
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
        io = StringIO.new
        io.set_encoding(Encoding::BINARY)
        gzip = Zlib::GzipWriter.new(io)
        gzip.write("beescows")
        gzip.close
        gzipped = io.string

        assert_equal gzipped, deflated_body.each.to_a.join
      end

      it "caches compressed content when size is called" do
        io = StringIO.new
        io.set_encoding(Encoding::BINARY)
        gzip = Zlib::GzipWriter.new(io)
        gzip.write("beescows")
        gzip.close
        gzipped = io.string

        assert_equal gzipped.bytesize, deflated_body.size
        assert_equal gzipped, deflated_body.each.to_a.join
      end

      it "reuses cached compression on subsequent size calls" do
        first_size = deflated_body.size

        assert_equal first_size, deflated_body.size
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
end
