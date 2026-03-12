# frozen_string_literal: true

module ConnectionReuseTests
  def self.included(base)
    base.class_eval do
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

          context "when previous response body was not read" do
            it "auto-flushes and completes the next request" do
              first_res = client.get(server.endpoint)
              second_res = client.get(server.endpoint)

              assert_equal "<!doctype html>", first_res.body.to_s
              assert_equal "<!doctype html>", second_res.body.to_s
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
              DummyServer::Servlet.sockets.each do |socket|
                socket.close
              rescue IOError
                nil
              end
              DummyServer::Servlet.sockets.clear

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
