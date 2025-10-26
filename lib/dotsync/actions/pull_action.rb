module Dotsync
  class PullAction < BaseAction
    include MappingsTransfer

    def_delegator :@config, :backups_root

    def execute
      show_config
      if create_backup
        show_backup
        purge_old_backups
      end
      pull_dotfiles
    end

    private

      def show_config
        show_mappings
      end

      def pull_dotfiles
        transfer_mappings

        action("Dotfiles pulled", icon: :copy)
      end

      def show_backup
        action("Backup created:", icon: :backup)
        logger.log("  #{backup_path}")
      end

      def timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def backup_path
        @backup_path ||= File.join(backups_root, timestamp)
      end

      def create_backup
        return false unless valid_mappings.any?
        FileUtils.mkdir_p(backup_path)
        mappings.each do |mapping|
          next unless File.exist?(mapping.dest)
          if File.file?(mapping.src)
            FileUtils.cp(mapping.dest, File.join(backup_path, File.basename(mapping.dest)))
          else
            FileUtils.cp_r(mapping.dest, File.join(backup_path, File.basename(mapping.dest)))
          end
        end
        true
      end

      def purge_old_backups
        backups = Dir[File.join(backups_root, '*')].sort.reverse
        if backups.size > 10
          info("Maximum of 10 backups retained")

          backups[10..].each do |path|
            FileUtils.rm_rf(path)
            info("Old backup deleted: #{path}", icon: :delete)
          end
        end
      end
  end
end
