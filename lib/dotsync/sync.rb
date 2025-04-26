module Dotsync
  class Sync
    include Loggable
    include Configurable

    def timestamp
      Time.now.strftime('%Y%m%d%H%M%S')
    end

    def create_backup
      FileUtils.mkdir_p(backup_root)
      backup_path = File.join(backup_root, "config-#{timestamp}")
      FileUtils.cp_r(dest, backup_path)
      log(:backup, "Backup created at #{backup_path}")
      cleanup_old_backups
    end

    def cleanup_old_backups
      backups = Dir[File.join(backup_root, 'config-*')].sort.reverse
      if backups.size > 10
        backups[10..].each do |path|
          FileUtils.rm_rf(path)
          log(:clean, "Old backup removed: #{path}")
        end
      end
    end

    def remove_conflicts
      Dir.glob("#{src}/**/*", File::FNM_DOTMATCH).each do |src_path|
        next if File.basename(src_path) == '.' || File.basename(src_path) == '..'

        relative_path = src_path.sub(/^#{Regexp.escape(src)}\//, '')
        dest_path = File.join(dest, relative_path)

        if File.exist?(dest_path)
          FileUtils.rm_rf(dest_path)
          log(:delete, "Removed #{dest_path}")
        end
      end
    end

    def sync_dotfiles
      FileUtils.mkdir_p(dest)
      FileUtils.cp_r(Dir["#{src}/*"], dest, remove_destination: false)
      log(:copy, "Dotfiles synced from #{src} to #{dest}")
    end

    def run!
      unless File.exist?(CONFIG_PATH)
        log(:error, "Configuration file not found at #{CONFIG_PATH}. Aborting sync.")
        return
      end

      log(:info, "Starting dotfile sync")
      create_backup
      remove_conflicts
      sync_dotfiles
      log(:done, "Dotfile sync complete ✔")
    end
  end
end
