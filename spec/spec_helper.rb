# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"

  enable_coverage :branch

  # Set thresholds based on current coverage (84.65% line, 70.61% branch)
  # Increase these as coverage improves
  minimum_coverage line: 84, branch: 70
end

require "dotsync"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    ENV["TEST_ENV"] = "true"
  end
end
