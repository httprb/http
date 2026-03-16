# frozen_string_literal: true

require_relative "support/simplecov"

require "minitest/autorun"
require "minitest/mock"
require "minitest/memory" if RUBY_ENGINE == "ruby"
require "minitest/strict"

require "http"

# No-op for mutant cover declarations when mutant is not loaded
Minitest::Test.extend(Module.new { def cover(*); end }) unless Minitest::Test.respond_to?(:cover)

require "support/capture_warning"
require "support/fakeio"

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
  class Test
    include FakeHelper
    include Minitest::Memory if RUBY_ENGINE == "ruby"
  end
end
