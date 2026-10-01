# frozen_string_literal: true

module ConnectionReuseTests
  # Including class must provide:
  #   - server: a DummyServer instance
  #   - build_client(**options): builds an HTTP::Client with given options

  def test_connection_reuse_enabled_infers_host_from_persistent
    client = build_client(persistent: server.endpoint)

    assert_equal "<!doctype html>", client.get("/").body.to_s
  end

  def test_connection_reuse_enabled_reuses_the_socket
    client = build_client(persistent: server.endpoint)
    sockets_used = [
      client.get("#{server.endpoint}/socket/1").body.to_s,
      client.get("#{server.endpoint}/socket/2").body.to_s
    ]

    refute_includes sockets_used, ""
    assert_equal 1, sockets_used.uniq.length
  end

  def test_connection_reuse_enabled_mixed_state_reopens_connection
    client = build_client(persistent: server.endpoint)
    first_socket_id = client.get("#{server.endpoint}/socket/1").body.to_s

    client.instance_variable_set(:@state, :dirty)

    second_socket_id = client.get("#{server.endpoint}/socket/2").body.to_s

    refute_equal first_socket_id, second_socket_id
  end

  def test_connection_reuse_enabled_auto_flushes_unread_body
    client = build_client(persistent: server.endpoint)
    first_res = client.get(server.endpoint)
    second_res = client.get(server.endpoint)

    assert_equal "<!doctype html>", first_res.body.to_s
    assert_equal "<!doctype html>", second_res.body.to_s
  end

  def test_connection_reuse_enabled_reading_cached_body_succeeds
    client = build_client(persistent: server.endpoint)
    first_res = client.get(server.endpoint)
    first_res.body.to_s

    second_res = client.get(server.endpoint)

    assert_equal "<!doctype html>", first_res.body.to_s
    assert_equal "<!doctype html>", second_res.body.to_s
  end

  def test_connection_reuse_enabled_socket_issue_transparently_reopens
    client = build_client(persistent: server.endpoint)
    first_socket_id = client.get("#{server.endpoint}/socket").body.to_s
    client_socket = idle_client_socket(client)

    refute_equal "", first_socket_id
    kill_server_sockets
    wait_for_server_bytes(client_socket)

    second_socket_id = client.get("#{server.endpoint}/socket").body.to_s

    refute_equal first_socket_id, second_socket_id
    assert_predicate client_socket, :closed?
  end

  def test_connection_reuse_enabled_socket_issue_transparently_reopens_for_post
    client = build_client(persistent: server.endpoint)
    client.get("#{server.endpoint}/socket").body.to_s
    client_socket = idle_client_socket(client)

    kill_server_sockets
    wait_for_server_bytes(client_socket)

    assert_equal "hello", client.post("#{server.endpoint}/sleep").body.to_s
    assert_predicate client_socket, :closed?
  end

  def test_connection_reuse_enabled_reopens_when_server_responds_while_idle
    client = build_client(persistent: server.endpoint)
    first_socket_id = client.get("#{server.endpoint}/socket").body.to_s
    client_socket = idle_client_socket(client)

    DummyServer::Servlet.sockets.each do |socket|
      socket.write("HTTP/1.1 408 Request Timeout\r\nContent-Length: 0\r\n\r\n")
    end
    DummyServer::Servlet.sockets.clear
    wait_for_server_bytes(client_socket)

    response = client.get("#{server.endpoint}/socket")

    assert_equal 200, response.code
    refute_equal first_socket_id, response.body.to_s
  end

  def test_connection_reuse_enabled_reopens_when_unread_body_is_too_large_to_flush
    client = build_client(persistent: server.endpoint)
    client.get("#{server.endpoint}/large")

    assert_equal "<!doctype html>", client.get(server.endpoint).body.to_s
  end

  def test_connection_reuse_enabled_raises_when_server_closes_after_receiving_request
    client = build_client(persistent: server.endpoint)
    client.get("#{server.endpoint}/socket").body.to_s

    assert_raises(HTTP::ConnectionError) { client.get("#{server.endpoint}/close") }
  end

  def test_connection_reuse_enabled_change_in_host_errors
    client = build_client(persistent: server.endpoint)

    err = assert_raises(HTTP::StateError) { client.get("https://invalid.com/socket") }
    assert_match(/Persistence is enabled/i, err.message)
  end

  def test_connection_reuse_disabled_opens_new_sockets
    client = build_client
    sockets_used = [
      client.get("#{server.endpoint}/socket/1").body.to_s,
      client.get("#{server.endpoint}/socket/2").body.to_s
    ]

    refute_includes sockets_used, ""
    assert_equal 2, sockets_used.uniq.length
  end

  private

  def idle_client_socket(client)
    client.instance_variable_get(:@connection).instance_variable_get(:@socket).socket.to_io
  end

  # Loopback delivers a close or write asynchronously; wait until it lands
  def wait_for_server_bytes(socket)
    assert socket.wait_readable(5), "server bytes never reached the client socket"
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
