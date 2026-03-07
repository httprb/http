# frozen_string_literal: true

require "bundler/gem_tasks"

require "minitest/test_task"
Minitest::TestTask.create do |t|
  t.libs << "test"
  t.test_globs = ["test/**/*_test.rb"]
  t.framework = 'require "test_helper"'
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "yardstick/rake/measurement"
Yardstick::Rake::Measurement.new do |measurement|
  measurement.output = "measurement/report.txt"
end

require "yardstick/rake/verify"
Yardstick::Rake::Verify.new do |verify|
  verify.require_exact_threshold = false
  verify.threshold = 100
end

desc "Type check with Steep"
task :steep do
  require "steep"
  require "steep/cli"
  exit Steep::CLI.new(argv: ["check", "--log-level=fatal"], stdout: $stdout, stderr: $stderr, stdin: $stdin).run
end

desc "Generate HTTP status codes from IANA registry"
task :generate_status_codes do
  require "http"
  require "nokogiri"

  url = "http://www.iana.org/assignments/http-status-codes/http-status-codes.xml"
  xml = Nokogiri::XML HTTP.get url
  excluded_descriptions = %w[Unassigned (Unused)]
  arr = xml.xpath("//xmlns:record").reduce([]) do |a, e|
    code = e.xpath("xmlns:value").text.to_s
    desc = e.xpath("xmlns:description").text.to_s

    next a if excluded_descriptions.include?(desc)

    a << "#{code} => #{desc.inspect}"
  end

  File.open("./lib/http/response/status/reasons.rb", "w") do |io|
    io.puts <<~TPL
      # AUTO-GENERATED FILE, DO NOT CHANGE IT MANUALLY

      require "delegate"

      module HTTP
        class Response
          class Status < ::Delegator
            # Code to Reason map
            #
            # @example Usage
            #
            #   REASONS[400] # => "Bad Request"
            #   REASONS[414] # => "Request-URI Too Long"
            #
            # @return [Hash<Fixnum => String>]
            REASONS = {
              #{arr.join ",\n              "}
            }.each { |_, v| v.freeze }.freeze
          end
        end
      end
    TPL
  end
end

desc "Run mutation testing with Mutant"
task :mutant do
  system("bundle exec mutant run") || abort("Mutant failed!")
end

task default: %i[test rubocop verify_measurements steep]
