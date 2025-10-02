module Dotsync
  class PullAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :backups_root

    def execute
      log(:info, "Starting dotfile sync")
      create_backup
      purge_old_backups
      remove_conflicts
      sync_dotfiles
      log(:done, "Dotfile sync complete ✔")
    end

    private

      def timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def create_backup
        FileUtils.mkdir_p(backups_root)
        backup_path = File.join(backups_root, "config-#{timestamp}")
        FileUtils.cp_r(dest, backup_path)
        log(:info, "Backup created at #{backup_path}", icon: :backup)
      end

      def purge_old_backups
        backups = Dir[File.join(backups_root, 'config-*')].sort.reverse
        if backups.size > 10
          backups[10..].each do |path|
            FileUtils.rm_rf(path)
            log(:info, "Old backup removed: #{path}", icon: :backup)
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
        log(:copy, "Dotfiles copied from #{src} to #{dest}")
      end
  end
end
