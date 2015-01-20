module ServerRunner
  def run_server(name)
    let! name do
      server = yield
      Thread.new { server.start }
      server
    end

    after { send(name).shutdown }
  end
end

RSpec.configure { |c| c.extend ServerRunner }
