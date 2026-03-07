# frozen_string_literal: true

require_relative "support/simplecov"

require "minitest/autorun"
require "minitest/mock"
require "minitest/memory"
require "minitest/strict"

require "http"

require "support/capture_warning"
require "support/fakeio"

# Add context as alias for describe in Minitest::Spec
module Minitest
  class Spec
    class << self
      alias context describe
    end
  end
end

# Helper for creating fake objects with predefined method responses
module FakeHelper
  def fake(**methods)
    obj = Object.new
    methods.each do |name, value|
      if value.is_a?(Proc)
        obj.define_singleton_method(name) { |*args, **kwargs, &blk| value.call(*args, **kwargs, &blk) }
      else
        obj.define_singleton_method(name) { |*| value }
      end
    end
    obj
  end
end

module Minitest
  class Spec
    include FakeHelper
    include Minitest::Memory
  end
end
