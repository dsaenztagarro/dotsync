module Dotsync
  module Configurable
    def check_config
      unless File.exist?(CONFIG_PATH)
        log(:error, "Config file not found at #{CONFIG_PATH}. Aborting sync.")
        abort
      end
    end

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
