# frozen_string_literal: true

module HTTPHandlingTests
  def self.included(base) # rubocop:disable Metrics/MethodLength
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

      describe "connection reuse" do
        let(:sockets_used) do
          [
            client.get("#{server.endpoint}/socket/1").body.to_s,
            client.get("#{server.endpoint}/socket/2").body.to_s
          ]
        end

        context "when enabled" do
          let(:options) { { persistent: server.endpoint } }

          context "without a host" do
            it "infers host from persistent config" do
              assert_equal "<!doctype html>", client.get("/").body.to_s
            end
          end

          it "re-uses the socket" do
            refute_includes sockets_used, ""
            assert_equal 1, sockets_used.uniq.length
          end

          context "on a mixed state" do
            it "re-opens the connection" do
              first_socket_id = client.get("#{server.endpoint}/socket/1").body.to_s

              client.instance_variable_set(:@state, :dirty)

              second_socket_id = client.get("#{server.endpoint}/socket/2").body.to_s

              refute_equal first_socket_id, second_socket_id
            end
          end

          context "when trying to read a stale body" do
            it "errors" do
              client.get("#{server.endpoint}/not-found")
              err = assert_raises(HTTP::StateError) { client.get(server.endpoint) }
              assert_match(/Tried to send a request/, err.message)
            end
          end

          context "when reading a cached body" do
            it "succeeds" do
              first_res = client.get(server.endpoint)
              first_res.body.to_s

              second_res = client.get(server.endpoint)

              assert_equal "<!doctype html>", first_res.body.to_s
              assert_equal "<!doctype html>", second_res.body.to_s
            end
          end

          context "with a socket issue" do
            it "transparently reopens" do
              first_socket_id = client.get("#{server.endpoint}/socket").body.to_s

              refute_equal "", first_socket_id
              # Kill off the sockets we used
              # rubocop:disable Style/RescueModifier
              DummyServer::Servlet.sockets.each do |socket|
                socket.close rescue nil
              end
              DummyServer::Servlet.sockets.clear
              # rubocop:enable Style/RescueModifier

              # Should error because we tried to use a bad socket
              assert_raises(HTTP::ConnectionError) do
                client.get("#{server.endpoint}/socket").body.to_s
              end

              # Should succeed since we create a new socket
              second_socket_id = client.get("#{server.endpoint}/socket").body.to_s

              refute_equal first_socket_id, second_socket_id
            end
          end

          context "with a change in host" do
            it "errors" do
              err = assert_raises(HTTP::StateError) { client.get("https://invalid.com/socket") }
              assert_match(/Persistence is enabled/i, err.message)
            end
          end
        end

        context "when disabled" do
          let(:options) { {} }

          it "opens new sockets" do
            refute_includes sockets_used, ""
            assert_equal 2, sockets_used.uniq.length
          end
        end
      end
    end
  end
end
