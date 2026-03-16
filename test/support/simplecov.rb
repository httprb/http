# frozen_string_literal: true

return if ENV["MUTANT"] || ENV["NOCOV"]

require "simplecov"

if ENV["CI"]
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config do |config|
    config.report_with_single_file = true
    config.lcov_file_name          = "lcov.info"
  end

  SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
end

SimpleCov.start do
  add_filter "/test/"
  add_filter "/minitest-memory/"

  if RUBY_ENGINE == "ruby"
    enable_coverage :branch
    minimum_coverage line: 100, branch: 100
  else
    minimum_coverage line: 99
  end
end
