module Dotsync
  class PullAction < BaseAction
    def_delegator :@config, :mappings
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
        info("Mappings:", icon: :source_dest)
        mappings.each do |mapping|
          force_icon = mapping.force? ? " #{icon_delete}" : ""
          info("  src: #{mapping.original_src} -> dest: #{mapping.original_dest}#{force_icon}", icon: :copy)
          info("    ignores: #{mapping.ignores.join(', ')}", icon: :exclude) if mapping.ignores.any?
        end
      end

      def show_backup
        action("Backup created:", icon: :backup)
        info("  #{backup_path}")
      end

      def timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def backup_path
        @backup_path ||= File.join(backups_root, timestamp)
      end

      def create_backup
        return false unless mappings.any? { |mapping| File.exist?(mapping.dest) }
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

      def pull_dotfiles
        mappings.each { |mapping| Dotsync::FileTransfer.new(mapping).transfer }
        action("Dotfiles pulled", icon: :copy)
      end

      def icon_delete
        Dotsync::Logger::ICONS[:delete]
      end
  end
end
