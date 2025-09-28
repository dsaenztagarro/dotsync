require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'dotsync'

# Load all tasks
Dir.glob(File.join(Gem.loaded_specs['dotsync'].full_gem_path, 'lib', 'dotsync', 'tasks', '**/*.rake')).each { |f| load f }

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "hello task"
task :hello do
  puts "hello world"
end

namespace :dotsync do
  desc "Sync Dotfiles"
  task :sync do
    ds = Dotsync::Sync.new
  end

  desc "Watch Dotfiles"
  task :watch do
    action = Dotsync::Watch.new
    action.start
  end
end

namespace :utils do
  desc "Show palette background"
  task :palette_bg do
    (0..255).each do |color|
      print "\e[48;5;#{color}m #{color.to_s.rjust(3)} \e[0m"
      puts if (color + 1) % 16 == 0
    end
  end

  desc "Show palette foreground"
  task :palette_fg do
    (0..255).each do |color|
      print "\e[38;5;#{color}m\e[1m #{color.to_s.rjust(3)} \e[0m"
      puts if (color + 1) % 16 == 0
    end
  end
end
