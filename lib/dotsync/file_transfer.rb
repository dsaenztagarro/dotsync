module Dotsync
  class FileTransfer
    extend Forwardable # def_delegator

    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :remove_dest
    def_delegator :@config, :excluded_paths

    def initialize(config)
      @config = config
    end

    def transfer
      do_transfer(src, dest)
    end

    private

      def do_transfer(local_src, local_dest)
        FileUtils.mkdir_p(local_dest)
        # The `remove_destination` option is used with file operations in Ruby,
        # such as `FileUtils.cp_r`. When set to `true`, it ensures that the
        # destination is removed before copying files or directories. This is
        # useful for overwriting existing files or directories without merging
        # their contents. Without this option, existing files in the destination
        # might remain, potentially causing issues with stale or conflicting data.
        Dir.glob("#{local_src}/*", File::FNM_DOTMATCH).each do |path|
          next if File.basename(path) == '.' || File.basename(path) == '..'

          path = File.expand_path(path)
          next if excluded_paths.include?(path) || path == local_src

          if File.file?(path)
            FileUtils.cp_r(path, local_dest, remove_destination: remove_dest)
          elsif excluded_paths.any? { |excluded_path| excluded_path.start_with?(path) }
            next_src = path
            next_dest = File.join(local_dest, File.basename(path))
            do_transfer(next_src, next_dest)
          else
            FileUtils.cp_r(path, local_dest, remove_destination: remove_dest)
          end
        end
      end
    end
end
