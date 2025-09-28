desc "Sync Dotfiles"
task :sync do
  ds = Dotsync::Sync.new
end

desc "Watch Dotfiles"
task :watch do
  action = Dotsync::Watch.new
  action.start
end
