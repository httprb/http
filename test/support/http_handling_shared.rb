# frozen_string_literal: true

require "support/http_handling_shared/timeout_tests"
require "support/http_handling_shared/connection_reuse_tests"

module HTTPHandlingTests
  def self.included(base)
    base.include TimeoutTests
    base.include ConnectionReuseTests
  end
end
