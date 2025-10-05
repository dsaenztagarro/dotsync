require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'dotsync'

# Load all tasks
Dir.glob(File.join(Gem.loaded_specs['dotsync'].full_gem_path, 'lib', 'dotsync', 'tasks', '**/*.rake')).each { |f| load f }

RSpec::Core::RakeTask.new(:spec) do |t|
  # ENV['TEST_ENV'] = 'true'
end

task default: :spec

desc "hello task"
task :hello do
  puts "hello world"
end

namespace :dotsync do
  desc "Pull Dotfiles"
  task :pull do
    Dotsync::Runner.new.run(:pull)
  end

  desc "Watch Dotfiles"
  task :watch do
    Dotsync::Runner.new.run(:watch)
  end
end

namespace :palette do
  desc "Show palette background"
  task :bg do
    (0..255).each do |color|
      print "\e[48;5;#{color}m #{color.to_s.rjust(3)} \e[0m"
      puts if (color + 1) % 16 == 0
    end
  end

  desc "Show palette foreground"
  task :fg do
    (0..255).each do |color|
      print "\e[38;5;#{color}m\e[1m #{color.to_s.rjust(3)} \e[0m"
      puts if (color + 1) % 16 == 0
    end
  end
end
