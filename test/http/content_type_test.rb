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

  describe "#deconstruct_keys" do
    let(:content_type) { HTTP::ContentType.new("text/html", "utf-8") }

    it "returns all keys when given nil" do
      assert_equal({ mime_type: "text/html", charset: "utf-8" }, content_type.deconstruct_keys(nil))
    end

    it "returns only requested keys" do
      assert_equal({ mime_type: "text/html" }, content_type.deconstruct_keys([:mime_type]))
    end

    it "excludes unrequested keys" do
      refute_includes content_type.deconstruct_keys([:mime_type]).keys, :charset
    end

    it "returns empty hash for empty keys" do
      assert_equal({}, content_type.deconstruct_keys([]))
    end

    it "returns nil values when attributes are nil" do
      ct = HTTP::ContentType.new

      assert_equal({ mime_type: nil, charset: nil }, ct.deconstruct_keys(nil))
    end

    it "supports pattern matching with case/in" do
      matched = case content_type
                in { mime_type: /html/ }
                  true
                else
                  false
                end

      assert matched
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
