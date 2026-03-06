# frozen_string_literal: true

require "test_helper"

describe HTTP::ContentType do
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
  end
end
