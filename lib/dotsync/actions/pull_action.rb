# frozen_string_literal: true

module Dotsync
  class PullAction < BaseAction
    include MappingsTransfer

    def_delegator :@config, :backups_root

    def execute
      show_config
      show_changes
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

        action("Dotfiles pulled")
      end

      def show_backup
        action("Backup created:")
        logger.log("  #{backup_root_path}")
      end

      def timestamp
        Time.now.strftime("%Y%m%d%H%M%S")
      end

      def backup_root_path
        @backup_root_path ||= File.join(backups_root, timestamp)
      end

      def create_backup
        return false unless valid_mappings.any?
        FileUtils.mkdir_p(backup_root_path)
        valid_mappings.each do |mapping|
          next unless mapping.backup_possible?
          backup_path = File.join(backup_root_path, mapping.backup_basename)
          if File.file?(mapping.src)
            FileUtils.cp(mapping.dest, backup_path)
          else
            FileUtils.cp_r(mapping.dest, backup_path)
          end
        end
        true
      end

      def purge_old_backups
        backups = Dir[File.join(backups_root, "*")].sort.reverse
        if backups.size > 10
          logger.log("Maximum of 10 backups retained")

          action("Backup deleted:")
          backups[10..].each do |path|
            FileUtils.rm_rf(path)
            logger.log("  #{path}")
          end
        end
      end
  end
end
