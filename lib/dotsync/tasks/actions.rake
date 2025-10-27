# frozen_string_literal: true

desc "Sync Dotfiles"
task :sync do
  Dotsync::SyncAction.new
end

desc "Watch Dotfiles"
task :watch do
  action = Dotsync::WatchAction.new
  action.start
end
