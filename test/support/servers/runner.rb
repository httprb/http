# frozen_string_literal: true

module ServerRunner
  @all_servers = []

  def self.all_servers
    @all_servers
  end

  def run_server(name)
    defining_class = self

    define_method(name) do
      cache = defining_class.instance_variable_get(:@_server_cache) ||
              defining_class.instance_variable_set(:@_server_cache, {})

      cache[name] ||= begin
        server = yield
        Thread.new { server.start }
        server.wait_ready
        ServerRunner.all_servers << server
        server
      end
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
    _all_run_servers.each do |s|
      server = send(s)
      server.reset if server.respond_to?(:reset)
    end
  end

  private

  def _all_run_servers
    klass = self.class
    servers = []

    while klass.respond_to?(:_run_servers)
      servers.concat(klass._run_servers)
      klass = klass.superclass
    end

    servers.uniq
  end
end

Minitest::Spec.extend(ServerRunner)
Minitest::Spec.include(ServerLifecycle)

Minitest.after_run do
  ServerRunner.all_servers.each do |server|
    server.shutdown
  rescue
    nil
  end
end
