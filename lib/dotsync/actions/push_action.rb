module Dotsync
  class PushAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :remove_dest
    def_delegator :@config, :excluded_paths

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
        if excluded_paths.any?
          info("Excluded paths:", icon: :skip)
          excluded_paths.each { |path| info("  #{path}") }
        end
        info("")
      end

      def sync_dotfiles
        FileUtils.mkdir_p(dest)
        # The `remove_destination` option is used with file operations in Ruby,
        # such as `FileUtils.cp_r`. When set to `true`, it ensures that the
        # destination is removed before copying files or directories. This is
        # useful for overwriting existing files or directories without merging
        # their contents. Without this option, existing files in the destination
        # might remain, potentially causing issues with stale or conflicting data.
        files_to_copy = Dir["#{src}/*"]
        files_to_copy = files_to_copy.reject do |path|
          excluded_paths.any? { |excluded| path.start_with?(File.join(src, excluded)) }
        end
        FileUtils.cp_r(files_to_copy, dest, remove_destination: remove_dest)
        action("Dotfiles pushed", icon: :copy)
      end
  end
end
