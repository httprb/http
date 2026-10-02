# frozen_string_literal: true

RSpec.shared_context "HTTP handling" do
  context "without timeouts" do
    let(:options) { {:timeout_class => HTTP::Timeout::Null, :timeout_options => {}} }

    it "works" do
      expect(client.get(server.endpoint).body.to_s).to eq("<!doctype html>")
    end
  end

  context "with a per operation timeout" do
    let(:response) { client.get(server.endpoint).body.to_s }

    let(:options) do
      {
        :timeout_class   => HTTP::Timeout::PerOperation,
        :timeout_options => {
          :connect_timeout => conn_timeout,
          :read_timeout    => read_timeout,
          :write_timeout   => write_timeout
        }
      }
    end
    let(:conn_timeout) { 1 }
    let(:read_timeout) { 1 }
    let(:write_timeout) { 1 }

    it "works" do
      expect(response).to eq("<!doctype html>")
    end

    context "connection" do
      context "of 1" do
        let(:conn_timeout) { 1 }

        it "does not time out" do
          expect { response }.to_not raise_error
        end
      end
    end

    context "read" do
      context "of 0" do
        let(:read_timeout) { 0 }

        it "times out", :flaky do
          expect { response }.to raise_error(HTTP::TimeoutError, /Read/i)
        end
      end

      context "of 2.5" do
        let(:read_timeout) { 2.5 }

        it "does not time out", :flaky do
          expect { client.get("#{server.endpoint}/sleep").body.to_s }.to_not raise_error
        end
      end
    end
  end

  context "with a global timeout" do
    let(:options) do
      {
        :timeout_class   => HTTP::Timeout::Global,
        :timeout_options => {
          :global_timeout => global_timeout
        }
      }
    end
    let(:global_timeout) { 1 }

    let(:response) { client.get(server.endpoint).body.to_s }

    it "errors if connecting takes too long" do
      expect(TCPSocket).to receive(:open) do
        sleep 1.25
      end

      expect { response }.to raise_error(HTTP::ConnectTimeoutError, /execution/)
    end

    it "errors if reading takes too long" do
      expect { client.get("#{server.endpoint}/sleep").body.to_s }.
        to raise_error(HTTP::TimeoutError, /Timed out/)
    end

    context "it resets state when reusing connections" do
      let(:extra_options) { {:persistent => server.endpoint} }

      let(:global_timeout) { 2.5 }

      it "does not timeout", :flaky do
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
      let(:options) { {:persistent => server.endpoint} }

      context "without a host" do
        it "infers host from persistent config" do
          expect(client.get("/").body.to_s).to eq("<!doctype html>")
        end
      end

      it "re-uses the socket" do
        expect(sockets_used).to_not include("")
        expect(sockets_used.uniq.length).to eq(1)
      end

      context "on a mixed state" do
        it "re-opens the connection", :flaky do
          first_socket_id = client.get("#{server.endpoint}/socket/1").body.to_s

          client.instance_variable_set(:@state, :dirty)

          second_socket_id = client.get("#{server.endpoint}/socket/2").body.to_s

          expect(first_socket_id).to_not eq(second_socket_id)
        end
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
        it "transparently reopens", :flaky do
          first_socket_id = client.get("#{server.endpoint}/socket").body.to_s
          expect(first_socket_id).to_not eq("")
          client_socket = idle_client_socket(client)

          kill_server_sockets
          wait_for_server_bytes(client_socket)

          second_socket_id = client.get("#{server.endpoint}/socket").body.to_s
          expect(second_socket_id).to_not eq(first_socket_id)
          expect(client_socket).to be_closed
        end

        it "transparently reopens for a POST", :flaky do
          client.get("#{server.endpoint}/socket").body.to_s
          client_socket = idle_client_socket(client)

          kill_server_sockets
          wait_for_server_bytes(client_socket)

          expect(client.post("#{server.endpoint}/echo-body", :body => "sent once").body.to_s).to eq("sent once")
          expect(client_socket).to be_closed
        end

        [
          [HTTP::Timeout::PerOperation, {:connect_timeout => 5, :read_timeout => 5, :write_timeout => 5}],
          [HTTP::Timeout::Global, {:global_timeout => 5}]
        ].each do |timeout_class, timeout_options|
          context "with #{timeout_class}" do
            let(:extra_options) { {:timeout_class => timeout_class, :timeout_options => timeout_options} }

            it "transparently reopens", :flaky do
              first_socket_id = client.get("#{server.endpoint}/socket").body.to_s
              client_socket = idle_client_socket(client)

              kill_server_sockets
              wait_for_server_bytes(client_socket)

              expect(client.get("#{server.endpoint}/socket").body.to_s).to_not eq(first_socket_id)
              expect(client_socket).to be_closed
            end
          end
        end
      end

      context "when the server responds while the connection is idle" do
        it "reopens instead of reading that response", :flaky do
          DummyServer::Servlet.sockets.clear
          first_socket_id = client.get("#{server.endpoint}/socket").body.to_s
          client_socket = idle_client_socket(client)

          DummyServer::Servlet.sockets.each do |socket|
            socket.write("HTTP/1.1 408 Request Timeout\r\nContent-Length: 0\r\n\r\n")
          end
          DummyServer::Servlet.sockets.clear
          wait_for_server_bytes(client_socket)

          response = client.get("#{server.endpoint}/socket")
          expect(response.code).to eq(200)
          expect(response.body.to_s).to_not eq(first_socket_id)
        end
      end

      context "when the server closes the connection after receiving the request" do
        it "raises" do
          client.get("#{server.endpoint}/socket").body.to_s

          expect { client.get("#{server.endpoint}/close") }.to raise_error(HTTP::ConnectionError)
        end
      end

      context "with a change in host" do
        it "errors" do
          expect { client.get("https://invalid.com/socket") }.to raise_error(/Persistence is enabled/i)
        end
      end
    end

    context "when disabled" do
      let(:options) { {} }

      it "opens new sockets", :flaky do
        expect(sockets_used).to_not include("")
        expect(sockets_used.uniq.length).to eq(2)
      end
    end
  end

  def idle_client_socket(client)
    client.instance_variable_get(:@connection).instance_variable_get(:@socket).socket.to_io
  end

  # Loopback delivers a close or write asynchronously; wait until it lands
  def wait_for_server_bytes(socket)
    expect(socket.wait_readable(5)).to be_truthy, "server bytes never reached the client socket"
  end

  def kill_server_sockets
    DummyServer::Servlet.sockets.each do |socket|
      socket.close
    rescue IOError
      nil
    end
    DummyServer::Servlet.sockets.clear
  end
end
