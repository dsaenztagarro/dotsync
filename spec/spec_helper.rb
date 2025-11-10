# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"

  enable_coverage :branch

  # Coverage thresholds - keep these high to maintain code quality
  # Current: 96.13% line, 81.14% branch
  minimum_coverage line: 95, branch: 80
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

  # Suppress print output during tests to keep terminal clean
  config.before(:each) do
    allow_any_instance_of(Kernel).to receive(:print)
  end
end
