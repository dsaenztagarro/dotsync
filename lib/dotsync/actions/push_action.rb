module Dotsync
  class PushAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :remove_dest
    def_delegator :@config, :excluded_paths

    def execute
      log_config
      push_dotfiles
    end

    private
      def log_config
        info("Source:", icon: :source)
        info("  #{src}")
        info("Destination:", icon: :dest)
        info("  #{dest}")
        info("Remove destination:", icon: :delete)
        info("  #{remove_dest}")
        if excluded_paths.any?
          info("Excluded paths:", icon: :skip)
          excluded_paths.sort.each { |path| info("  #{path}") }
        end
        info("")
      end

      def push_dotfiles
        push_dotfiles_for(src, dest)
      end

      def push_dotfiles_for(local_src, local_dest)
        FileUtils.mkdir_p(local_dest)
        # The `remove_destination` option is used with file operations in Ruby,
        # such as `FileUtils.cp_r`. When set to `true`, it ensures that the
        # destination is removed before copying files or directories. This is
        # useful for overwriting existing files or directories without merging
        # their contents. Without this option, existing files in the destination
        # might remain, potentially causing issues with stale or conflicting data.
        Dir["#{local_src}/**"].each do |path|
          if excluded_paths.include?(path)
            # do nothing
          elsif excluded_paths.any? { |excluded_path| excluded_path.start_with?(path) }
            (Dir["#{path}/**"] - excluded_paths).each do |subpath|
              next_src = path
              next_dest = File.join(local_dest, File.basename(path))
              push_dotfiles_for(next_src, next_dest)
            end
          else
            FileUtils.cp_r(path, local_dest, remove_destination: remove_dest)
          end
        end
        action("Dotfiles pushed", icon: :copy)
      end

      def exclude_paths(paths)
        paths.reject do |path|
          excluded_paths.any? { |excluded_path| path.start_with?(excluded_path) }
        end
      end
  end
end
