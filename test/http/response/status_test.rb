# frozen_string_literal: true

require "test_helper"

describe HTTP::Response::Status do
  cover "HTTP::Response::Status*"
  describe ".new" do
    it "fails if given value does not respond to #to_i" do
      assert_raises(TypeError) { HTTP::Response::Status.new(Object.new) }
    end

    it "accepts any object that responds to #to_i" do
      HTTP::Response::Status.new(fake(to_i: 200))
    end
  end

  describe "#code" do
    let(:status) { HTTP::Response::Status.new("200.0") }

    it "returns the integer code" do
      assert_equal 200, status.code
    end

    it "is an Integer" do
      assert_kind_of Integer, status.code
    end
  end

  describe "#reason" do
    context "with unknown code" do
      it "returns nil" do
        assert_nil HTTP::Response::Status.new(1024).reason
      end
    end

    HTTP::Response::Status::REASONS.each do |code, reason|
      context "with well-known code: #{code}" do
        it "returns #{reason.inspect}" do
          assert_equal reason, HTTP::Response::Status.new(code).reason
        end

        it "is frozen" do
          assert_predicate HTTP::Response::Status.new(code).reason, :frozen?
        end
      end
    end
  end

  all_category_methods = %i[informational? success? redirect? client_error? server_error?]

  {
    100...200 => :informational?,
    200...300 => :success?,
    300...400 => :redirect?,
    400...500 => :client_error?,
    500...600 => :server_error?
  }.each do |range, positive_method|
    context "with #{range.first / 100}xx codes" do
      let(:statuses) { range.map { |code| HTTP::Response::Status.new(code) } }

      it "is ##{positive_method}" do
        assert(statuses.all?(&positive_method))
      end

      (all_category_methods - [positive_method]).each do |method|
        it "is not ##{method}" do
          assert(statuses.none?(&method))
        end
      end
    end
  end

  describe "#to_sym" do
    context "with unknown code" do
      it "returns nil" do
        assert_nil HTTP::Response::Status.new(1024).to_sym
      end
    end

    HTTP::Response::Status::SYMBOLS.each do |code, symbol|
      context "with well-known code: #{code}" do
        it "returns #{symbol.inspect}" do
          assert_equal symbol, HTTP::Response::Status.new(code).to_sym
        end
      end
    end
  end

  describe "#inspect" do
    it "returns quoted code and reason phrase" do
      status = HTTP::Response::Status.new(200)

      assert_equal "#<HTTP::Response::Status 200 OK>", status.inspect
    end
  end

  describe "::SYMBOLS" do
    it "maps 200 to :ok" do
      assert_equal :ok, HTTP::Response::Status::SYMBOLS[200]
    end

    it "maps 400 to :bad_request" do
      assert_equal :bad_request, HTTP::Response::Status::SYMBOLS[400]
    end
  end

  HTTP::Response::Status::SYMBOLS.each do |code, symbol|
    describe "##{symbol}?" do
      context "when code is #{code}" do
        it "returns true" do
          assert HTTP::Response::Status.new(code).send(:"#{symbol}?")
        end
      end

      context "when code is higher than #{code}" do
        it "returns false" do
          refute HTTP::Response::Status.new(code + 1).send(:"#{symbol}?")
        end
      end

      context "when code is lower than #{code}" do
        it "returns false" do
          refute HTTP::Response::Status.new(code - 1).send(:"#{symbol}?")
        end
      end
    end
  end

  describe "#to_s" do
    it "strips trailing whitespace for unknown codes" do
      assert_equal "1024", HTTP::Response::Status.new(1024).to_s
    end
  end

  describe "#__setobj__" do
    it "includes the inspected object in the error message" do
      obj = Object.new
      def obj.to_s = "custom"

      err = assert_raises(TypeError) { HTTP::Response::Status.new(obj) }
      assert_match(/#<Object:0x\h+>/, err.message)
      refute_includes err.message, "custom"
    end
  end

  describe "#deconstruct_keys" do
    let(:status) { HTTP::Response::Status.new(200) }

    it "returns all keys when given nil" do
      assert_equal({ code: 200, reason: "OK" }, status.deconstruct_keys(nil))
    end

    it "returns only requested keys" do
      result = status.deconstruct_keys([:code])

      assert_equal({ code: 200 }, result)
    end

    it "excludes unrequested keys" do
      refute_includes status.deconstruct_keys([:code]).keys, :reason
    end

    it "returns empty hash for empty keys" do
      assert_equal({}, status.deconstruct_keys([]))
    end

    it "returns nil reason for unknown code" do
      unknown = HTTP::Response::Status.new(1024)

      assert_equal({ code: 1024, reason: nil }, unknown.deconstruct_keys(nil))
    end

    it "supports pattern matching with case/in" do
      matched = case status
                in { code: 200..299 }
                  true
                else
                  false
                end

      assert matched
    end

    it "supports pattern matching with specific code" do
      matched = case status
                in { code: 200, reason: "OK" }
                  true
                else
                  false
                end

      assert matched
    end
  end

  describe "boundary conditions" do
    it "code 99 is not informational" do
      refute_predicate HTTP::Response::Status.new(99), :informational?
    end

    it "code 600 is not server_error" do
      refute_predicate HTTP::Response::Status.new(600), :server_error?
    end
  end

  describe ".coerce" do
    context "with String" do
      it "coerces reasons" do
        assert_equal HTTP::Response::Status.new(400), HTTP::Response::Status.coerce("Bad request")
      end

      it "coerces hyphenated reasons" do
        assert_equal HTTP::Response::Status.new(207), HTTP::Response::Status.coerce("Multi-Status")
      end

      it "coerces reasons with multiple words" do
        assert_equal HTTP::Response::Status.new(203), HTTP::Response::Status.coerce("Non-Authoritative Information")
      end

      it "fails when reason is unknown" do
        assert_raises(HTTP::Error) { HTTP::Response::Status.coerce("foobar") }
      end
    end

    context "with Symbol" do
      it "coerces symbolized reasons" do
        assert_equal HTTP::Response::Status.new(400), HTTP::Response::Status.coerce(:bad_request)
      end

      it "fails when symbolized reason is unknown" do
        assert_raises(HTTP::Error) { HTTP::Response::Status.coerce(:foobar) }
      end
    end

    context "with Numeric" do
      it "coerces as Fixnum code" do
        assert_equal HTTP::Response::Status.new(200), HTTP::Response::Status.coerce(200.1)
      end
    end

    it "returns a Status instance" do
      result = HTTP::Response::Status.coerce(:ok)

      assert_instance_of HTTP::Response::Status, result
    end

    it "fails if coercion failed" do
      err = assert_raises(HTTP::Error) { HTTP::Response::Status.coerce(true) }
      assert_includes err.message, "TrueClass"
      assert_includes err.message, "true"
      assert_includes err.message, "HTTP::Response::Status"
    end

    it "is aliased as `.[]`" do
      status = HTTP::Response::Status[:ok]

      assert_equal 200, status.code
    end
  end
end
