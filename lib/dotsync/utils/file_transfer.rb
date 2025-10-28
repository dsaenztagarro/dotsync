# frozen_string_literal: true

module Dotsync
  class FileTransfer
    attr_reader :ignores

    def initialize(config)
      @src = config.src
      @dest = config.dest
      @force = config.force?
      @ignores = config.ignores || []
    end

    def transfer
      if File.file?(@src)
        transfer_file(@src, @dest)
      else
        FileUtils.rm_rf(Dir.glob(File.join(@dest, "*"))) if @force
        transfer_folder(@src, @dest)
      end
    end

    private

      def transfer_file(file_src, file_dest)
        FileUtils.mkdir_p(File.dirname(file_dest))
        FileUtils.cp(file_src, file_dest)
      end

      def transfer_folder(folder_src, folder_dest)
        FileUtils.mkdir_p(folder_dest)
        Dir.glob("#{folder_src}/*", File::FNM_DOTMATCH).each do |path|
          next if [".", ".."].include?(File.basename(path))

          full_path = File.expand_path(path)
          next if ignore?(full_path)

          target = File.join(folder_dest, File.basename(path))
          if File.file?(full_path)
            FileUtils.cp(full_path, target)
          else
            transfer_folder(full_path, target)
          end
        end
      end

      def ignore?(path)
        @ignores.any? { |ignore| path.start_with?(ignore) }
      end
  end
end
