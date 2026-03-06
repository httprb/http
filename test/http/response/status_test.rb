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

  context "with 1xx codes" do
    let(:statuses) { (100...200).map { |code| HTTP::Response::Status.new(code) } }

    it "is #informational?" do
      assert statuses.all?(&:informational?)
    end

    it "is not #success?" do
      assert(statuses.all? { |status| !status.success? })
    end

    it "is not #redirect?" do
      assert(statuses.all? { |status| !status.redirect? })
    end

    it "is not #client_error?" do
      assert(statuses.all? { |status| !status.client_error? })
    end

    it "is not #server_error?" do
      assert(statuses.all? { |status| !status.server_error? })
    end
  end

  context "with 2xx codes" do
    let(:statuses) { (200...300).map { |code| HTTP::Response::Status.new(code) } }

    it "is not #informational?" do
      assert(statuses.all? { |status| !status.informational? })
    end

    it "is #success?" do
      assert statuses.all?(&:success?)
    end

    it "is not #redirect?" do
      assert(statuses.all? { |status| !status.redirect? })
    end

    it "is not #client_error?" do
      assert(statuses.all? { |status| !status.client_error? })
    end

    it "is not #server_error?" do
      assert(statuses.all? { |status| !status.server_error? })
    end
  end

  context "with 3xx codes" do
    let(:statuses) { (300...400).map { |code| HTTP::Response::Status.new(code) } }

    it "is not #informational?" do
      assert(statuses.all? { |status| !status.informational? })
    end

    it "is not #success?" do
      assert(statuses.all? { |status| !status.success? })
    end

    it "is #redirect?" do
      assert statuses.all?(&:redirect?)
    end

    it "is not #client_error?" do
      assert(statuses.all? { |status| !status.client_error? })
    end

    it "is not #server_error?" do
      assert(statuses.all? { |status| !status.server_error? })
    end
  end

  context "with 4xx codes" do
    let(:statuses) { (400...500).map { |code| HTTP::Response::Status.new(code) } }

    it "is not #informational?" do
      assert(statuses.all? { |status| !status.informational? })
    end

    it "is not #success?" do
      assert(statuses.all? { |status| !status.success? })
    end

    it "is not #redirect?" do
      assert(statuses.all? { |status| !status.redirect? })
    end

    it "is #client_error?" do
      assert statuses.all?(&:client_error?)
    end

    it "is not #server_error?" do
      assert(statuses.all? { |status| !status.server_error? })
    end
  end

  context "with 5xx codes" do
    let(:statuses) { (500...600).map { |code| HTTP::Response::Status.new(code) } }

    it "is not #informational?" do
      assert(statuses.all? { |status| !status.informational? })
    end

    it "is not #success?" do
      assert(statuses.all? { |status| !status.success? })
    end

    it "is not #redirect?" do
      assert(statuses.all? { |status| !status.redirect? })
    end

    it "is not #client_error?" do
      assert(statuses.all? { |status| !status.client_error? })
    end

    it "is #server_error?" do
      assert statuses.all?(&:server_error?)
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
