# frozen_string_literal: true

module TimeoutTests
  # Including class must provide:
  #   - server: a DummyServer instance
  #   - build_client(**options): builds an HTTP::Client with given options

  def test_timeout_without_timeouts_works
    client = build_client(timeout_class: HTTP::Timeout::Null, timeout_options: {})

    assert_equal "<!doctype html>", client.get(server.endpoint).body.to_s
  end

  def test_timeout_per_operation_works
    client = build_client(
      timeout_class:   HTTP::Timeout::PerOperation,
      timeout_options: {
        connect_timeout: 0.5,
        read_timeout:    0.1,
        write_timeout:   0.5
      }
    )

    assert_equal "<!doctype html>", client.get(server.endpoint).body.to_s
  end

  def test_timeout_per_operation_connection_of_half_second_does_not_time_out
    client = build_client(
      timeout_class:   HTTP::Timeout::PerOperation,
      timeout_options: {
        connect_timeout: 0.5,
        read_timeout:    0.1,
        write_timeout:   0.5
      }
    )

    client.get(server.endpoint).body.to_s
  end

  def test_timeout_per_operation_read_of_zero_times_out
    client = build_client(
      timeout_class:   HTTP::Timeout::PerOperation,
      timeout_options: {
        connect_timeout: 0.5,
        read_timeout:    0,
        write_timeout:   0.5
      }
    )

    err = assert_raises(HTTP::TimeoutError) do
      client.get("#{server.endpoint}/sleep").body.to_s
    end
    assert_match(/Read/i, err.message)
  end

  def test_timeout_per_operation_read_of_tenth_does_not_time_out
    client = build_client(
      timeout_class:   HTTP::Timeout::PerOperation,
      timeout_options: {
        connect_timeout: 0.5,
        read_timeout:    0.1,
        write_timeout:   0.5
      }
    )

    client.get("#{server.endpoint}/sleep").body.to_s
  end

  def test_timeout_global_errors_if_connecting_takes_too_long
    client = build_client(
      timeout_class:   HTTP::Timeout::Global,
      timeout_options: { global_timeout: 0.01 }
    )

    TCPSocket.stub(:open, ->(*) { sleep 0.025 }) do
      err = assert_raises(HTTP::ConnectTimeoutError) { client.get(server.endpoint).body.to_s }
      assert_match(/execution/, err.message)
    end
  end

  def test_timeout_global_errors_if_reading_takes_too_long
    client = build_client(
      timeout_class:   HTTP::Timeout::Global,
      timeout_options: { global_timeout: 0.01 }
    )

    err = assert_raises(HTTP::TimeoutError) do
      client.get("#{server.endpoint}/sleep").body.to_s
    end
    assert_match(/Timed out|execution expired/, err.message)
  end

  def test_timeout_global_resets_state_when_reusing_connections
    client = build_client(
      timeout_class:   HTTP::Timeout::Global,
      timeout_options: { global_timeout: 0.5 },
      persistent:      server.endpoint
    )

    client.get("#{server.endpoint}/sleep").body.to_s
    client.get("#{server.endpoint}/sleep").body.to_s
  end

  def test_timeout_combined_global_and_per_operation_works
    client = build_client(
      timeout_class:   HTTP::Timeout::Global,
      timeout_options: {
        global_timeout:  0.5,
        connect_timeout: 0.25,
        read_timeout:    0.25,
        write_timeout:   0.25
      }
    )

    assert_equal "<!doctype html>", client.get(server.endpoint).body.to_s
  end

  def test_timeout_combined_per_op_read_of_zero_times_out
    client = build_client(
      timeout_class:   HTTP::Timeout::Global,
      timeout_options: {
        global_timeout:  0.5,
        connect_timeout: 0.25,
        read_timeout:    0,
        write_timeout:   0.25
      }
    )

    err = assert_raises(HTTP::TimeoutError) do
      client.get("#{server.endpoint}/sleep").body.to_s
    end
    assert_match(/Read timed out/, err.message)
  end
end
