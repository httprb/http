module ServerRunner
  def run_server(name, &_block)
    let! name do
      server = yield

      Thread.new { server.start }

      server
    end

    after do
      send(name).shutdown
    end
  end
end

RSpec.configure { |c| c.extend ServerRunner }
