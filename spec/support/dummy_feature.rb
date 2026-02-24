# frozen_string_literal: true

class DummyFeature < HTTP::Feature
  class << self
    def instance
      @instance ||=
        begin
          i = allocate
          i.send(:initialize)
          i
        end
    end

    def new
      instance
    end
  end

  def initialize
    super
    reset!
  end

  attr_reader :wrap_request_called_with, :wrap_response_called_with, :on_error_called_with

  def wrap_request(request)
    @wrap_request_called_with << request
  end

  def wrap_response(response)
    @wrap_response_called_with << response
  end

  def on_error(request, error)
    @on_error_called_with << [request, error]
  end

  def reset!
    @wrap_request_called_with = []
    @wrap_response_called_with = []
    @on_error_called_with = []
  end

  HTTP::Options.register_feature(:dummy, self)
end

RSpec.configure do |config|
  config.before do
    DummyFeature.instance.reset!
  end
end
