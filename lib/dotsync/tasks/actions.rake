desc "Sync Dotfiles"
task :sync do
  ds = Dotsync::SyncAction.new
end

desc "Watch Dotfiles"
task :watch do
  action = Dotsync::WatchAction.new
  action.start
end
