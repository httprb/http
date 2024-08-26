# frozen_string_literal: true

RSpec.describe HTTP::Retriable::Performer do
  let(:client) do
    HTTP::Client.new
  end

  let(:response) do
    HTTP::Response.new(
      status:  200,
      version: "1.1",
      headers: {},
      body:    "Hello world!",
      request: request
    )
  end

  let(:request) do
    HTTP::Request.new(
      verb: :get,
      uri:  "http://example.com"
    )
  end

  let(:perform_spy) { { counter: 0 } }
  let(:counter_spy) { perform_spy[:counter] }

  before do
    stub_const("CustomException", Class.new(StandardError))
  end

  def perform(options = {}, client_arg = client, request_arg = request, &block)
    # by explicitly overwriting the default delay, we make a much faster test suite
    default_options = { delay: 0 }
    options = default_options.merge(options)

    HTTP::Retriable::Performer
      .new(options)
      .perform(client_arg, request_arg) do
        perform_spy[:counter] += 1
        block ? yield : response
      end
  end

  def measure_wait
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    [t2 - t1, result]
  end

  describe "#perform" do
    describe "expected exception" do
      it "retries the request" do
        expect do
          perform(exceptions: [CustomException], tries: 2) do
            raise CustomException
          end
        end.to raise_error HTTP::OutOfRetriesError

        expect(counter_spy).to eq 2
      end
    end

    describe "unexpected exception" do
      it "does not retry the request" do
        expect do
          perform(exceptions: [], tries: 2) do
            raise CustomException
          end
        end.to raise_error CustomException

        expect(counter_spy).to eq 1
      end
    end

    describe "expected status codes" do
      def response(**options)
        HTTP::Response.new(
          {
            status:  200,
            version: "1.1",
            headers: {},
            body:    "Hello world!",
            request: request
          }.merge(options)
        )
      end

      it "retries the request" do
        expect do
          perform(retry_statuses: [200], tries: 2)
        end.to raise_error HTTP::OutOfRetriesError

        expect(counter_spy).to eq 2
      end

      describe "status codes can be expressed in many ways" do
        [
          301,
          [200, 301, 485],
          250...400,
          [250...Float::INFINITY],
          ->(status_code) { status_code == 301 },
          [->(status_code) { status_code == 301 }]
        ].each do |retry_statuses|
          it retry_statuses.to_s do
            expect do
              perform(retry_statuses: retry_statuses, tries: 2) do
                response(status: 301)
              end
            end.to raise_error HTTP::OutOfRetriesError
          end
        end
      end
    end

    describe "unexpected status code" do
      it "does not retry the request" do
        expect(
          perform(retry_statuses: [], tries: 2)
        ).to eq response

        expect(counter_spy).to eq 1
      end
    end

    describe "on_retry callback" do
      it "calls the on_retry callback on each retry with exception" do
        callback_call_spy = 0

        callback_spy = proc do |callback_request, error, callback_response|
          expect(callback_request).to eq request
          expect(error).to be_a HTTP::TimeoutError
          expect(callback_response).to be_nil
          callback_call_spy += 1
        end

        expect do
          perform(tries: 3, on_retry: callback_spy) do
            raise HTTP::TimeoutError
          end
        end.to raise_error HTTP::OutOfRetriesError

        expect(callback_call_spy).to eq 2
      end

      it "calls the on_retry callback on each retry with response" do
        callback_call_spy = 0

        callback_spy = proc do |callback_request, error, callback_response|
          expect(callback_request).to eq request
          expect(error).to be_nil
          expect(callback_response).to be response
          callback_call_spy += 1
        end

        expect do
          perform(retry_statuses: [200], tries: 3, on_retry: callback_spy)
        end.to raise_error HTTP::OutOfRetriesError

        expect(callback_call_spy).to eq 2
      end
    end

    describe "delay option" do
      let(:timing_slack) { 0.05 }

      it "can be a positive number" do
        time, = measure_wait do
          perform(delay: 0.1, tries: 3, should_retry: ->(*) { true })
        rescue HTTP::OutOfRetriesError
        end
        expect(time).to be_within(timing_slack).of(0.2)
      end

      it "can be a proc number" do
        time, = measure_wait do
          perform(delay: ->(attempt) { attempt / 10.0 }, tries: 3, should_retry: ->(*) { true })
        rescue HTTP::OutOfRetriesError
        end
        expect(time).to be_within(timing_slack).of(0.3)
      end

      it "receives correct retry number when a proc" do
        retry_count = 0
        retry_proc = proc do |attempt|
          expect(attempt).to eq(retry_count).and(be > 0)
          0
        end
        begin
          perform(delay: retry_proc, should_retry: ->(*) { true }) do
            retry_count += 1
            response
          end
        rescue HTTP::OutOfRetriesError
        end
      end
    end

    describe "should_retry option" do
      it "decides if the request should be retried" do # rubocop:disable RSpec/MultipleExpectations
        retry_proc = proc do |req, err, res, attempt|
          expect(req).to eq request
          if res
            expect(err).to be_nil
            expect(res).to be response
          else
            expect(err).to be_a CustomException
            expect(res).to be_nil
          end

          attempt < 5
        end

        begin
          perform(should_retry: retry_proc) do
            rand < 0.5 ? response : raise(CustomException)
          end
        rescue CustomException
        end

        expect(counter_spy).to eq 5
      end

      it "raises the original error if not retryable" do
        retry_proc = ->(*) { false }

        expect do
          perform(should_retry: retry_proc) do
            raise CustomException
          end
        end.to raise_error CustomException

        expect(counter_spy).to eq 1
      end

      it "raises HTTP::OutOfRetriesError if retryable" do
        retry_proc = ->(*) { true }

        expect do
          perform(should_retry: retry_proc) do
            raise CustomException
          end
        end.to raise_error HTTP::OutOfRetriesError

        expect(counter_spy).to eq 5
      end
    end
  end

  describe "connection closing" do
    let(:client) { double(:client) }

    it "does not close the connection if we get a propper response" do
      expect(client).not_to receive(:close)
      perform
    end

    it "closes the connection after each raiseed attempt" do
      expect(client).to receive(:close).exactly(3).times
      begin
        perform(should_retry: ->(*) { true }, tries: 3)
      rescue HTTP::OutOfRetriesError
      end
    end

    it "closes the connection on an unexpected exception" do
      expect(client).to receive(:close)
      begin
        perform do
          raise CustomException
        end
      rescue CustomException
      end
    end
  end

  describe HTTP::OutOfRetriesError do
    it "has the original exception as a cause if available" do
      err = nil
      begin
        perform(exceptions: [CustomException]) do
          raise CustomException
        end
      rescue described_class => e
        err = e
      end
      expect(err.cause).to be_a CustomException
    end

    it "has the last raiseed response as an attribute" do
      err = nil
      begin
        perform(should_retry: ->(*) { true })
      rescue described_class => e
        err = e
      end
      expect(err.response).to be response
    end
  end
end
