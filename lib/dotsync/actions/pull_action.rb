module Dotsync
  class PullAction < BaseAction
    def_delegator :@config, :mappings
    def_delegator :@config, :backups_root

    def execute
      show_config
      # create_backup
      # purge_old_backups
      pull_dotfiles
    end

    private
      def show_config
        info("Mappings:", icon: :source_dest)
        mappings.each do |mapping|
          info("  Source: #{mapping[:src]} -> Destination: #{mapping[:dest]}")
        end

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
        mappings.each do |mapping|
          FileUtils.cp_r(mapping[:dest], File.join(backup_path, File.basename(mapping[:dest])))
        end
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

      def pull_dotfiles
        mappings.each do |mapping|
          Dotsync::FileTransfer.new(mapping).transfer
        end

        action("Dotfiles pulled", icon: :copy)
      end
  end
end
