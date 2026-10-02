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

    refute_equal "", first_socket_id
    kill_server_sockets

    # A GET is resent once on a new socket
    second_socket_id = client.get("#{server.endpoint}/socket").body.to_s

    refute_equal "", second_socket_id
    refute_equal first_socket_id, second_socket_id
  end

  def test_connection_reuse_enabled_socket_issue_raises_for_non_idempotent_request
    client = build_client(persistent: server.endpoint)
    first_socket_id = client.get("#{server.endpoint}/socket").body.to_s

    refute_equal "", first_socket_id
    kill_server_sockets

    # Should error because a POST is not resent
    assert_raises(HTTP::ConnectionError) do
      client.post("#{server.endpoint}/sleep").body.to_s
    end

    # Should succeed since we create a new socket
    second_socket_id = client.get("#{server.endpoint}/socket").body.to_s

    refute_equal first_socket_id, second_socket_id
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

  def kill_server_sockets
    DummyServer::Servlet.sockets.each do |socket|
      socket.close
    rescue IOError
      nil
    end
    DummyServer::Servlet.sockets.clear
  end
end
