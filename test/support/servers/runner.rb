# frozen_string_literal: true

module ServerRunner
  def run_server(name)
    let(name) do
      server = yield
      Thread.new { server.start }
      server
    end

    _run_servers << name
  end

  def _run_servers
    @_run_servers ||= []
  end
end

module ServerLifecycle
  def setup
    super
    self.class._run_servers.each { |s| send(s) } if self.class.respond_to?(:_run_servers)
  end

  def teardown
    self.class._run_servers.each { |s| send(s).shutdown } if self.class.respond_to?(:_run_servers)
    super
  end
end

Minitest::Spec.extend(ServerRunner)
Minitest::Spec.include(ServerLifecycle)
