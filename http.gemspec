# frozen_string_literal: true

require_relative "./lib/http/version"

Gem::Specification.new do |spec|
  spec.name          = "http"
  spec.version       = HTTP::VERSION
  spec.authors       = ["Tony Arcieri", "Erik Michaels-Ober", "Alexey V. Zapparov", "Zachary Anker"]
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
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    extras = %w[CHANGELOG.md LICENSE.txt README.md SECURITY.md] << File.basename(__FILE__)

    ls.readlines("\x0", chomp: true).select do |f|
      f.start_with?("lib/", "spec/") || extras.include?(f)
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.filter_map { |f| File.basename(f) if f.start_with?("exe/") }
  spec.test_files    = spec.files.select { |f| f.start_with?("spec/") }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "addressable",    "~> 2.8"
  spec.add_dependency "http-cookie",    "~> 1.0"
  spec.add_dependency "http-form_data", "~> 2.2"

  # Use native llhttp for MRI (more performant) and llhttp-ffi for other interpreters (better compatibility)
  if RUBY_ENGINE == "ruby"
    spec.add_dependency "llhttp", "~> 0.6.1"
  else
    spec.add_dependency "llhttp-ffi", "~> 0.5.1"
  end
end
