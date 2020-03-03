# frozen_string_literal: true

# rubocop:disable Lint/HandleExceptions
RSpec.describe HTTP::Retriable::Performer do
  let(:client) do
    HTTP::Client.new
  end
  let(:response) do
    HTTP::Response.new(
      :status  => 200,
      :version => "1.1",
      :headers => {},
      :body    => "Hello world!",
      :uri     => "http://example.com/",
      :request => request
    )
  end
  let(:request) do
    HTTP::Request.new(
      :verb => :get,
      :uri  => "http://example.com"
    )
  end

  CustomException = Class.new(StandardError)

  let(:perform_spy) { {:counter => 0} }
  let(:counter_spy) { perform_spy[:counter] }

  def perform(options = {}, client_arg = client, request_arg = request, &block)
    # by explicitly overwriting the default delay, we make a much faster test suite
    default_options = {:delay => 0}
    options = default_options.merge(options)

    HTTP::Retriable::Performer.
      new(options).
      perform(client_arg, request_arg) do
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
          perform(:exceptions => [CustomException], :tries => 2) do
            raise CustomException
          end
        end.to raise_error HTTP::OutOfRetriesError

        expect(counter_spy).to eq 2
      end
    end

    describe "unexpected exception" do
      it "does not retry the request" do
        expect do
          perform(:exceptions => [], :tries => 2) do
            raise CustomException
          end
        end.to raise_error CustomException

        expect(counter_spy).to eq 1
      end
    end

    describe "expected status codes" do
      it "retries the request" do
        expect do
          perform(:retry_statuses => [200], :tries => 2)
        end.to raise_error HTTP::OutOfRetriesError

        expect(counter_spy).to eq 2
      end
    end

    describe "unexpected status code" do
      it "does not retry the request" do
        expect(
          perform(:retry_statuses => [], :tries => 2)
        ).to eq response

        expect(counter_spy).to eq 1
      end
    end

    describe "on_retry callback" do
      it "calls the on_retry callback on each retry with exception" do
        callback_call_spy = 0

        callback_spy = ->(request, error, response) do
          expect(request).to eq request
          expect(error).to be_a HTTP::TimeoutError
          expect(response).to be_nil
          callback_call_spy += 1
        end

        expect do
          perform(:tries => 3, :on_retry => callback_spy) do
            raise HTTP::TimeoutError
          end
        end.to raise_error HTTP::OutOfRetriesError

        expect(callback_call_spy).to eq 2
      end

      it "calls the on_retry callback on each retry with response" do
        callback_call_spy = 0

        callback_spy = ->(request, error, response) do
          expect(request).to eq request
          expect(error).to be_nil
          expect(response).to be response
          callback_call_spy += 1
        end

        expect do
          perform(:retry_statuses => [200], :tries => 3, :on_retry => callback_spy)
        end.to raise_error HTTP::OutOfRetriesError

        expect(callback_call_spy).to eq 2
      end
    end

    describe "delay option" do
      let(:timing_slack) { 0.05 }

      it "can be a positive number" do
        time, = measure_wait do
          begin
            perform(:delay => 0.1, :tries => 3, :should_retry => ->(*) { true })
          rescue HTTP::OutOfRetriesError
          end
        end
        expect(time).to be_within(timing_slack).of(0.2)
      end

      it "can be a proc number" do
        time, = measure_wait do
          begin
            perform(:delay => ->(i) { i / 10.0 }, :tries => 3, :should_retry => ->(*) { true })
          rescue HTTP::OutOfRetriesError
          end
        end
        expect(time).to be_within(timing_slack).of(0.3)
      end

      it "receives correct retry number when a proc" do
        retry_count = 0
        retry_proc = ->(i) {
          expect(i).to eq(retry_count).and(be > 0)
          0
        }
        begin
          perform(:delay => retry_proc, :should_retry => ->(*) { true }) do
            retry_count += 1
            response
          end
        rescue HTTP::OutOfRetriesError
        end
      end
    end

    describe "should_retry option" do
      it "decides if the request should be retried" do
        retry_proc = ->(req, err, res, i) do
          expect(req).to eq request
          if res
            expect(err).to be_nil
            expect(res).to be response
          else
            expect(err).to be_a CustomException
            expect(res).to be_nil
          end

          i < 5
        end

        begin
          perform(:should_retry => retry_proc) do
            rand < 0.5 ? response : raise(CustomException)
          end
        rescue CustomException
        end

        expect(counter_spy).to eq 5
      end

      it "raises the original error if not retryable" do
        retry_proc = ->(*) { false }

        expect do
          perform(:should_retry => retry_proc) do
            raise CustomException
          end
        end.to raise_error CustomException

        expect(counter_spy).to eq 1
      end

      it "raises HTTP::OutOfRetriesError if retryable" do
        retry_proc = ->(*) { true }

        expect do
          perform(:should_retry => retry_proc) do
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
      expect(client).to_not receive(:close)
      perform
    end

    it "closes the connection after each raiseed attempt" do
      expect(client).to receive(:close).exactly(3).times
      begin
        perform(:should_retry => ->(*) { true }, :tries => 3)
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
        perform(:exceptions => [CustomException]) do
          raise CustomException
        end
      rescue HTTP::OutOfRetriesError => e
        err = e
      end
      expect(err.cause).to be_a CustomException
    end

    it "has the last raiseed response as an attribute" do
      err = nil
      begin
        perform(:should_retry => ->(*) { true })
      rescue HTTP::OutOfRetriesError => e
        err = e
      end
      expect(err.response).to be response
    end
  end

  describe "delay calculation" do
    def call_delay(iterations, **options)
      HTTP::Retriable::Performer.new(options).calculate_delay_from_iteration(iterations)
    end

    def call_retry_header(value, **options)
      HTTP::Retriable::Performer.new(options).delay_from_retry_header(value)
    end

    it "prevents negative sleep time" do
      expect(call_delay(20, :delay => -20)).to eq 0
    end

    it "backs off exponentially" do
      expect(call_delay(1)).to be_between 0, 1
      expect(call_delay(2)).to be_between 1, 2
      expect(call_delay(3)).to be_between 3, 4
      expect(call_delay(4)).to be_between 7, 8
      expect(call_delay(5)).to be_between 15, 16
    end

    it "can have a maximum wait time" do
      expect(call_delay(1, :max_delay => 5)).to be_between 0, 1
      expect(call_delay(5, :max_delay => 5)).to eq 5
    end

    it "respects Retry-After headers as integer" do
      delay_time = rand(6...2500)
      header_value = delay_time.to_s
      expect(call_retry_header(header_value)).to eq delay_time
      expect(call_retry_header(header_value, :max_delay => 5)).to eq 5
    end

    it "respects Retry-After headers as rfc2822 timestamp" do
      delay_time = rand(6...2500)
      header_value = (Time.now.gmtime + delay_time).to_datetime.rfc2822.sub("+0000", "GMT")
      expect(call_retry_header(header_value)).to be_within(1).of(delay_time)
      expect(call_retry_header(header_value, :max_delay => 5)).to eq 5
    end

    it "respects Retry-After headers as rfc2822 timestamp in the past" do
      delay_time = rand(6...2500)
      header_value = (Time.now.gmtime - delay_time).to_datetime.rfc2822.sub("+0000", "GMT")
      expect(call_retry_header(header_value)).to eq 0
    end

    it "does not error on invalid Retry-After header" do
      [ # invalid strings
        "This is a string with a number 5 in it",
        "8 Eight is the first digit in this string",
        "This is a string with a #{Time.now.gmtime.to_datetime.rfc2822} timestamp in it"
      ].each do |header_value|
        expect(call_retry_header(header_value)).to eq 0
      end
    end
  end
end
# rubocop:enable Lint/HandleExceptions
