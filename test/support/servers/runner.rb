# frozen_string_literal: true

module ServerRunner
  def run_server(name)
    let(name) do
      server = yield
      Thread.new { server.start }
      server
    end

    before { send(name) }

    after { send(name).shutdown }
  end
end

Minitest::Spec.extend(ServerRunner)
