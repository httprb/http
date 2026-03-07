# frozen_string_literal: true

require "test_helper"

describe HTTP::Response::Status do
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

  describe ".coerce" do
    context "with String" do
      it "coerces reasons" do
        assert_equal HTTP::Response::Status.new(400), HTTP::Response::Status.coerce("Bad request")
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

    it "fails if coercion failed" do
      assert_raises(HTTP::Error) { HTTP::Response::Status.coerce(true) }
    end

    it "is aliased as `.[]`" do
      assert_equal HTTP::Response::Status.method(:coerce), HTTP::Response::Status.method(:[])
    end
  end
end
