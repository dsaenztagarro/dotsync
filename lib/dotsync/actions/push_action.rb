module Dotsync
  class PushAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :remove_dest

    def execute
      log_config
      sync_dotfiles
    end

    private
      def log_config
        info("Source:", icon: :source)
        info("  #{src}")
        info("Destination:", icon: :dest)
        info("  #{dest}")
        info("Remove destination:", icon: :copy)
        info("  #{remove_dest}")
        info("")
      end

      def timestamp
        Time.now.strftime('%Y%m%d%H%M%S')
      end

      def sync_dotfiles
        FileUtils.mkdir_p(dest)
        # The `remove_destination` option is used with file operations in Ruby,
        # such as `FileUtils.cp_r`. When set to `true`, it ensures that the
        # destination is removed before copying files or directories. This is
        # useful for overwriting existing files or directories without merging
        # their contents. Without this option, existing files in the destination
        # might remain, potentially causing issues with stale or conflicting data.
        FileUtils.cp_r(Dir["#{src}/*"], dest, remove_destination: remove_dest)
        action("Dotfiles pushed", icon: :copy)
      end
  end
end
