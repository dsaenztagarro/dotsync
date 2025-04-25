module Dotsync
  class Sync
    include Loggable

    # 🛠️ Configurable paths
    SRC = File.expand_path('~/Code/dotfiles/src/.config')
    DEST = File.expand_path('~/.config')
    BACKUP_ROOT = File.expand_path('~/.local/share/dotfile_backups')

    def timestamp
      Time.now.strftime('%Y%m%d%H%M%S')
    end

    def create_backup
      FileUtils.mkdir_p(BACKUP_ROOT)
      backup_path = File.join(BACKUP_ROOT, "config-#{timestamp}")
      FileUtils.cp_r(DEST, backup_path)
      log(:backup, "Backup created at #{backup_path}")
      cleanup_old_backups
    end

    def cleanup_old_backups
      backups = Dir[File.join(BACKUP_ROOT, 'config-*')].sort.reverse
      if backups.size > 10
        backups[10..].each do |path|
          FileUtils.rm_rf(path)
          log(:clean, "Old backup removed: #{path}")
        end
      end
    end

    def remove_conflicts
      Dir.glob("#{SRC}/**/*", File::FNM_DOTMATCH).each do |src_path|
        next if File.basename(src_path) == '.' || File.basename(src_path) == '..'

        relative_path = src_path.sub(/^#{Regexp.escape(SRC)}\//, '')
        dest_path = File.join(DEST, relative_path)

        if File.exist?(dest_path)
          FileUtils.rm_rf(dest_path)
          log(:delete, "Removed #{dest_path}")
        end
      end
    end

    def sync_dotfiles
      FileUtils.mkdir_p(DEST)
      FileUtils.cp_r(Dir["#{SRC}/*"], DEST, remove_destination: false)
      log(:copy, "Dotfiles synced from #{SRC} to #{DEST}")
    end

    def run!
      log(:info, "Starting dotfile sync")
      create_backup
      remove_conflicts
      sync_dotfiles
      log(:done, "Dotfile sync complete ✔")
    end
  end
end
