RSpec.shared_context "handles shared connections" do
  describe "connection reuse" do
    let(:sockets_used) do
      [
        client.get("#{server.endpoint}/socket/1").body.to_s,
        client.get("#{server.endpoint}/socket/2").body.to_s
      ]
    end

    context "when enabled" do
      let(:reuse_conn) { server.endpoint }

      context "without a host" do
        it "infers host from persistent config" do
          expect(client.get("/").body.to_s).to eq("<!doctype html>")
        end
      end

      it "re-uses the socket" do
        expect(sockets_used).to_not include("")
        expect(sockets_used.uniq.length).to eq(1)
      end

      context "when trying to read a stale body" do
        it "errors" do
          client.get("#{server.endpoint}/not-found")
          expect { client.get(server.endpoint) }.to raise_error(HTTP::StateError, /Tried to send a request/)
        end
      end

      context "when reading a cached body" do
        it "succeeds" do
          first_res = client.get(server.endpoint)
          first_res.body.to_s

          second_res = client.get(server.endpoint)

          expect(first_res.body.to_s).to eq("<!doctype html>")
          expect(second_res.body.to_s).to eq("<!doctype html>")
        end
      end

      context "with a socket issue" do
        it "transparently reopens" do
          skip "flaky environment" if flaky_env?

          first_socket = client.get("#{server.endpoint}/socket").body.to_s
          expect(first_socket).to_not eq("")

          # Kill off the sockets we used
          # rubocop:disable Style/RescueModifier
          DummyServer::Servlet.sockets.each do |socket|
            socket.close rescue nil
          end
          DummyServer::Servlet.sockets.clear
          # rubocop:enable Style/RescueModifier

          # Should error because we tried to use a bad socket
          expect { client.get("#{server.endpoint}/socket").body.to_s }.to raise_error(IOError)

          # Should succeed since we create a new socket
          second_socket = client.get("#{server.endpoint}/socket").body.to_s
          expect(second_socket).to_not eq(first_socket)
        end
      end

      context "with a Keep-Alive timeout of 0" do
        let(:keep_alive_timeout) { 0 }

        it "automatically opens a new socket" do
          first_socket = client.get("#{server.endpoint}/socket/1").body.to_s
          sleep 0.1
          second_socket = client.get("#{server.endpoint}/socket/2").body.to_s

          expect(first_socket).to_not eq(second_socket)
        end
      end

      context "with a change in host" do
        it "errors" do
          expect { client.get("https://invalid.com/socket") }.to raise_error(/Persistence is enabled/i)
        end
      end
    end

    context "when disabled" do
      let(:reuse_conn) { nil }

      it "opens new sockets" do
        expect(sockets_used).to_not include("")
        expect(sockets_used.uniq.length).to eq(2)
      end
    end
  end
end
