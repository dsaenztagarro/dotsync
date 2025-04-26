module Dotsync
  module Configurable
    CONFIG_PATH = File.expand_path('~/.config/dotsync.toml')
    CONFIG = TomlRB.load_file(CONFIG_PATH)

    def self.src
      File.expand_path(CONFIG['paths']['src'])
    end

    def self.dest
      File.expand_path(CONFIG['paths']['dest'])
    end

    def self.backup_root
      File.expand_path(CONFIG['paths']['backup_root'])
    end
  end
end
