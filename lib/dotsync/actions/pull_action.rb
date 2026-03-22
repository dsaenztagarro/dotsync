# frozen_string_literal: true

module Dotsync
  class PullAction < BaseAction
    include MappingsTransfer
    include OutputSections

    def_delegator :@config, :backups_root
    def_delegator :@config, :manifests_xdg_data_home

    def execute(options = {})
      output_sections = compute_output_sections(options)

      show_options(options) if output_sections[:options]
      show_env_vars if output_sections[:env_vars]
      show_mappings_legend if output_sections[:mappings_legend]
      show_mappings if output_sections[:mappings]
      show_differences_legend if has_differences? && output_sections[:differences_legend]
      show_differences(diff_content: output_sections[:diff_content]) if output_sections[:differences]
      show_hooks_preview(force: options[:force_hooks]) if output_sections[:differences]

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
      cleanup_orphans
      execute_hooks(force: options[:force_hooks])
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
            cp_r_regular_files(mapping.dest, backup_path)
          end
        end
        true
      end

      # Recursively copy a directory, skipping sockets, FIFOs, and device files.
      # FileUtils.cp_r fails on macOS when socket paths exceed the 104-byte limit.
      def cp_r_regular_files(src, dest)
        FileUtils.mkdir_p(dest)
        Dir.each_child(src) do |entry|
          src_entry = File.join(src, entry)
          dest_entry = File.join(dest, entry)
          if File.symlink?(src_entry)
            FileUtils.rm_f(dest_entry)
            FileUtils.ln_s(File.readlink(src_entry), dest_entry)
          elsif File.directory?(src_entry)
            cp_r_regular_files(src_entry, dest_entry)
          elsif File.file?(src_entry)
            FileUtils.cp(src_entry, dest_entry, preserve: true)
          end
        end
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
