# frozen_string_literal: true

module TimeoutTests
  def self.included(base)
    base.class_eval do
      context "without timeouts" do
        let(:options) { { timeout_class: HTTP::Timeout::Null, timeout_options: {} } }

        it "works" do
          assert_equal "<!doctype html>", client.get(server.endpoint).body.to_s
        end
      end

      context "with a per operation timeout" do
        let(:response) { client.get(server.endpoint).body.to_s }

        let(:options) do
          {
            timeout_class:   HTTP::Timeout::PerOperation,
            timeout_options: {
              connect_timeout: conn_timeout,
              read_timeout:    read_timeout,
              write_timeout:   write_timeout
            }
          }
        end
        let(:conn_timeout) { 0.1 }
        let(:read_timeout) { 0.1 }
        let(:write_timeout) { 0.1 }

        it "works" do
          assert_equal "<!doctype html>", response
        end

        context "connection of 0.1" do
          let(:conn_timeout) { 0.1 }

          it "does not time out" do
            response
          end
        end

        context "read of 0" do
          let(:read_timeout) { 0 }

          it "times out" do
            err = assert_raises(HTTP::TimeoutError) { response }
            assert_match(/Read/i, err.message)
          end
        end

        context "read of 0.1" do
          let(:read_timeout) { 0.1 }

          it "does not time out" do
            client.get("#{server.endpoint}/sleep").body.to_s
          end
        end
      end

      context "with a global timeout" do
        let(:options) do
          {
            timeout_class:   HTTP::Timeout::Global,
            timeout_options: {
              global_timeout: global_timeout
            }
          }
        end
        let(:global_timeout) { 0.025 }

        let(:response) { client.get(server.endpoint).body.to_s }

        it "errors if connecting takes too long" do
          TCPSocket.stub(:open, ->(*) { sleep 0.05 }) do
            err = assert_raises(HTTP::ConnectTimeoutError) { response }
            assert_match(/execution/, err.message)
          end
        end

        it "errors if reading takes too long" do
          err = assert_raises(HTTP::TimeoutError) do
            client.get("#{server.endpoint}/sleep").body.to_s
          end
          assert_match(/Timed out/, err.message)
        end

        context "it resets state when reusing connections" do
          let(:extra_options) { { persistent: server.endpoint } }

          let(:global_timeout) { 0.15 }

          it "does not timeout" do
            client.get("#{server.endpoint}/sleep").body.to_s
            client.get("#{server.endpoint}/sleep").body.to_s
          end
        end
      end

      context "with combined global and per-operation timeouts" do
        let(:options) do
          {
            timeout_class:   HTTP::Timeout::Global,
            timeout_options: {
              global_timeout:  1.0,
              connect_timeout: 0.5,
              read_timeout:    read_timeout,
              write_timeout:   0.5
            }
          }
        end
        let(:read_timeout) { 0.5 }

        let(:response) { client.get(server.endpoint).body.to_s }

        it "works for normal requests" do
          assert_equal "<!doctype html>", response
        end

        context "read of 0" do
          let(:read_timeout) { 0 }

          it "errors if per-op read times out" do
            err = assert_raises(HTTP::TimeoutError) do
              client.get("#{server.endpoint}/sleep").body.to_s
            end
            assert_match(/Read timed out/, err.message)
          end
        end
      end
    end
  end
end
