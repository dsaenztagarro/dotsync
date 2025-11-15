# frozen_string_literal: true

module Dotsync
  class FileTransfer
    # Initializes a new FileTransfer instance
    #
    # @param mapping [Dotsync::Mapping] the mapping object containing source, destination, force, and ignore details
    # @option mapping [String] :src the source directory path
    # @option mapping [String] :dest the destination directory path
    # @option mapping [Boolean] :force? optional flag to force actions
    # @option mapping [Array<String>] :ignores optional list of files/directories to ignore
    def initialize(mapping)
      @mapping = mapping
      @src = mapping.src
      @dest = mapping.dest
      @force = mapping.force?
      @inclusions = mapping.inclusions || []
      @ignores = mapping.ignores || []
    end

    def transfer
      if File.file?(@src)
        transfer_file(@src, @dest)
      else
        cleanup_folder(@dest, @ignores, @inclusions) if @force
        transfer_folder(@src, @dest)
      end
    end

    private
      attr_reader :mapping, :ignores

      def transfer_file(file_src, file_dest)
        FileUtils.mkdir_p(File.dirname(file_dest))
        FileUtils.cp(file_src, file_dest)
      end

      def transfer_folder(folder_src, folder_dest)
        FileUtils.mkdir_p(folder_dest)

        # `Dir.glob("#{folder_src}/*")` retrieves only the immediate contents
        # (files and directories) within the specified directory (`folder_src`),
        # without descending into subdirectories.

        Dir.glob("#{folder_src}/*", File::FNM_DOTMATCH).each do |path|
          next if [".", ".."].include?(File.basename(path))

          full_path = File.expand_path(path)
          next unless mapping.bidirectional_include?(full_path)
          next if mapping.ignore?(full_path)

          target = File.join(folder_dest, File.basename(path))
          if File.file?(full_path)
            FileUtils.cp(full_path, target)
          else
            transfer_folder(full_path, target)
          end
        end
      end

      def cleanup_folder(target_dir, exclusions = [], inclusions = [])
        exclusions = exclusions.map { |ex| File.expand_path(ex) }
        target_dir = File.expand_path(target_dir)

        # The `Find.find` method in Ruby performs a depth-first traversal of the
        # file hierarchy. This means it will explore all files and subdirectories
        # within a directory before returning to process the parent directory.
        # Because of this order, `FileUtils.rmdir` can be executed safely at the
        # end of the traversal, as all files and subdirectories within a directory
        # would have already been processed and removed.

        Find.find(target_dir) do |path|
          next if path == target_dir
          abs_path = File.expand_path(path)

          # Skip if excluded
          if exclusions.any? { |ex| abs_path.start_with?(ex) }
            Find.prune if File.directory?(path)
            next
          end

          # When inclusions are specified, only clean up paths that match the inclusion filter
          # This ensures we don't delete unrelated files/folders that aren't being managed
          if inclusions.any?
            # Convert destination path to source path to check against inclusions
            relative_path = abs_path.delete_prefix(File.join(target_dir, "/"))
            src_path = File.join(@src, relative_path)

            unless inclusions.any? { |inc| src_path.start_with?(inc) || inc.start_with?(src_path) }
              Find.prune if File.directory?(path)
              next
            end
          end

          if File.file?(path)
            FileUtils.rm(path)
          elsif File.directory?(path) && Dir.empty?(path)
            FileUtils.rmdir(path)
          end
        end
      end
  end
end
