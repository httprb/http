module ServerRunner
  def run_server(name, &block)
    let! name do
      server = block.call
      thread = Thread.new { server.start }

      Thread.pass while thread.status != "sleep"

      server
    end

    after do
      send(name).shutdown
    end
  end
end

RSpec.configure { |c| c.extend ServerRunner }
