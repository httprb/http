# frozen_string_literal: true

require_relative "lib/http/version"

Gem::Specification.new do |spec|
  spec.name          = "http"
  spec.version       = HTTP::VERSION
  spec.authors       = ["Tony Arcieri", "Erik Berlin", "Alexey V. Zapparov", "Zachary Anker"]
  spec.email         = ["bascule@gmail.com"]

  spec.summary       = "HTTP should be easy"
  spec.homepage      = "https://github.com/httprb/http"
  spec.license       = "MIT"

  spec.description   = <<~DESCRIPTION.strip.gsub(/\s+/, " ")
    An easy-to-use client library for making requests from Ruby.
    It uses a simple method chaining system for building requests,
    similar to Python's Requests.
  DESCRIPTION

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = "#{spec.homepage}/tree/v#{spec.version}"
  spec.metadata["bug_tracker_uri"]       = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["documentation_uri"]     = "https://www.rubydoc.info/gems/http/#{spec.version}"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    extras = %w[LICENSE.txt README.md sig/http.rbs] << File.basename(__FILE__)

    ls.readlines("\x0", chomp: true).select do |f|
      f.start_with?("lib/") || extras.include?(f)
    end
  end

  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "http-cookie", "~> 1.0"

  if RUBY_ENGINE == "jruby"
    spec.platform = "java" if ENV["HTTP_PLATFORM"] == "java"
    spec.add_dependency "llhttp-ffi", "~> 0.5.1"
  else
    spec.add_dependency "llhttp", "~> 0.6.1"
  end
end
