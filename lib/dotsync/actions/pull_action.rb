# frozen_string_literal: true

module Dotsync
  class PullAction < BaseAction
    include MappingsTransfer
    include OutputSections

    def_delegator :@config, :backups_root

    def execute(options = {})
      output_sections = compute_output_sections(options)

      show_options(options) if output_sections[:options]
      show_env_vars if output_sections[:env_vars]
      show_mappings_legend if output_sections[:mappings_legend]
      show_mappings if output_sections[:mappings]
      show_differences_legend if has_differences? && output_sections[:differences_legend]
      show_differences if output_sections[:differences]

      return unless options[:apply]

      # Confirmation prompt unless --yes flag is provided or no differences
      if has_differences? && !options[:yes] && !options[:quiet]
        return unless confirm_action
      end

      if has_differences?
        if create_backup
          show_backup
          purge_old_backups
        end
      end

      transfer_mappings
      action("Mappings pulled", icon: :done)
    end

    private
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
          action("Oldest backup deleted:")
          backups[10..].each do |path|
            FileUtils.rm_rf(path)
            logger.log("  #{path}")
          end
        end
      end
  end
end
