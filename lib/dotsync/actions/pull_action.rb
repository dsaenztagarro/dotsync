module Dotsync
  class PullAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :backups_root

    def execute
      log_config
      create_backup
      purge_old_backups
      remove_destination
      pull_dotfiles
    end

    private
      def log_config
        info("Source:", icon: :source)
        info("  #{src}")
        info("Destination:", icon: :dest)
        info("  #{dest}")
        info("Backups root:", icon: :backup)
        info("  #{backups_root}")
        info("")
      end

      def timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def create_backup
        FileUtils.mkdir_p(backups_root)
        backup_path = File.join(backups_root, "config-#{timestamp}")
        FileUtils.cp_r(dest, backup_path)
        action("Backup created:", icon: :backup)
        info("  #{backup_path}")
      end

      def purge_old_backups
        backups = Dir[File.join(backups_root, 'config-*')].sort.reverse
        if backups.size > 10
          info("Maximum of 10 backups retained")

          backups[10..].each do |path|
            FileUtils.rm_rf(path)
            info("Old backup deleted: #{path}", icon: :delete)
          end
        end
      end

      def remove_destination
        removed_from_dest = []
        # Iterate through all files and directories in the source, including hidden ones
        Dir.glob("#{src}/**/*", File::FNM_DOTMATCH).each do |src_path|
          next if File.basename(src_path) == '.' || File.basename(src_path) == '..'

          relative_path = src_path.sub(/^#{Regexp.escape(src)}\//, '')
          dest_path = File.join(dest, relative_path)

          if File.exist?(dest_path)
            FileUtils.rm_rf(dest_path)
            removed_from_dest << dest_path
          end
        end
        if removed_from_dest.any?
          logger.warning("Removed from destination", icon: :delete)
          removed_from_dest.each do |removed_path|
            info("  #{removed_path}")
          end
        end
      end

      def pull_dotfiles
        FileUtils.mkdir_p(dest)
        FileUtils.cp_r(Dir["#{src}/*"], dest, remove_destination: false)
        action("Dotfiles pulled", icon: :copy)
      end
  end
end
