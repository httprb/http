module ServerRunner
  def run_server(name, &block)
    let! name do
      server = block.call

      Thread.new { server.start }

      server
    end

    after do
      send(name).shutdown
    end
  end
end

RSpec.configure { |c| c.extend ServerRunner }
