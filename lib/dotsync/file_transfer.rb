module Dotsync
  class FileTransfer
    def initialize(config)
      @src = config[:src]
      @dest = config[:dest]
      @force = config[:force]
      @excluded_paths = config[:excluded_paths] || []
    end

    def transfer
      if File.file?(@src)
        transfer_file(@src, @dest)
      else
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
        next if ['.', '..'].include?(File.basename(path))

        full_path = File.expand_path(path)
        next if excluded_path?(full_path)

        target = File.join(folder_dest, File.basename(path))
        if File.file?(full_path)
          FileUtils.cp(full_path, target)
        else
          transfer_folder(full_path, target)
        end
      end
    end

    def excluded_path?(path)
      @excluded_paths.any? { |excluded| path.start_with?(File.expand_path(excluded)) }
    end
  end
end
