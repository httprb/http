# frozen_string_literal: true

require "test_helper"

describe HTTP::ContentType do
  cover "HTTP::ContentType*"
  describe ".parse" do
    context "with text/plain" do
      let(:subject_under_test) { HTTP::ContentType.parse "text/plain" }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_nil subject_under_test.charset
      end
    end

    context "with tEXT/plaIN" do
      let(:subject_under_test) { HTTP::ContentType.parse "tEXT/plaIN" }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_nil subject_under_test.charset
      end
    end

    context "with text/plain; charset=utf-8" do
      let(:subject_under_test) { HTTP::ContentType.parse "text/plain; charset=utf-8" }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_equal "utf-8", subject_under_test.charset
      end
    end

    context 'with text/plain; charset="utf-8"' do
      let(:subject_under_test) { HTTP::ContentType.parse 'text/plain; charset="utf-8"' }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_equal "utf-8", subject_under_test.charset
      end
    end

    context "with text/plain; charSET=utf-8" do
      let(:subject_under_test) { HTTP::ContentType.parse "text/plain; charSET=utf-8" }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_equal "utf-8", subject_under_test.charset
      end
    end

    context "with text/plain; foo=bar; charset=utf-8" do
      let(:subject_under_test) { HTTP::ContentType.parse "text/plain; foo=bar; charset=utf-8" }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_equal "utf-8", subject_under_test.charset
      end
    end

    context "with text/plain;charset=utf-8;foo=bar" do
      let(:subject_under_test) { HTTP::ContentType.parse "text/plain;charset=utf-8;foo=bar" }

      it "has correct mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "has correct charset" do
        assert_equal "utf-8", subject_under_test.charset
      end
    end

    context "with nil" do
      let(:subject_under_test) { HTTP::ContentType.parse nil }

      it "returns nil mime_type" do
        assert_nil subject_under_test.mime_type
      end

      it "returns nil charset" do
        assert_nil subject_under_test.charset
      end
    end

    context "with empty string" do
      let(:subject_under_test) { HTTP::ContentType.parse "" }

      it "returns nil mime_type" do
        assert_nil subject_under_test.mime_type
      end

      it "returns nil charset" do
        assert_nil subject_under_test.charset
      end
    end

    context "with whitespace around mime type" do
      let(:subject_under_test) { HTTP::ContentType.parse " text/plain ; charset= utf-8 " }

      it "strips whitespace from mime_type" do
        assert_equal "text/plain", subject_under_test.mime_type
      end

      it "strips whitespace from charset" do
        assert_equal "utf-8", subject_under_test.charset
      end
    end
  end

  describe "#initialize" do
    it "stores mime_type and charset" do
      ct = HTTP::ContentType.new("text/html", "utf-8")

      assert_equal "text/html", ct.mime_type
      assert_equal "utf-8", ct.charset
    end

    it "defaults to nil" do
      ct = HTTP::ContentType.new

      assert_nil ct.mime_type
      assert_nil ct.charset
    end
  end
end
