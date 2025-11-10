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
        # Check if we're trying to overwrite a directory with a file
        if File.exist?(@dest) && File.directory?(@dest) && !File.symlink?(@dest)
          # If @dest is a directory and NOT just a parent directory for the file,
          # this is a conflict. The check is: if @dest path exactly matches where
          # we want the file to be (not a parent dir), then it's a conflict.
          # We determine this by checking if File.basename(@src) already appears
          # to be accounted for in @dest path.
          dest_basename = File.basename(@dest)
          src_basename = File.basename(@src)

          if dest_basename == src_basename
            raise Dotsync::TypeConflictError, "Cannot overwrite directory '#{@dest}' with file '#{@src}'"
          end
        end

        # If dest is a directory, compute the target file path
        target_dest = if File.directory?(@dest)
          File.join(@dest, File.basename(@src))
        else
          @dest
        end
        transfer_file(@src, target_dest)
      else
        cleanup_folder(@dest) if @force
        transfer_folder(@src, @dest)
      end
    end

    private
      attr_reader :mapping, :ignores

      def transfer_file(file_src, file_dest)
        # Check for type conflicts before transfer
        if File.exist?(file_dest) && File.directory?(file_dest)
          raise Dotsync::TypeConflictError, "Cannot overwrite directory '#{file_dest}' with file '#{file_src}'"
        end

        FileUtils.mkdir_p(File.dirname(file_dest))

        # Use atomic write: copy to temp file, then rename
        # This prevents corruption if copy is interrupted
        temp_file = "#{file_dest}.tmp.#{Process.pid}"
        begin
          FileUtils.cp(file_src, temp_file)
          FileUtils.mv(temp_file, file_dest, force: true)
        rescue Errno::EACCES, Errno::EPERM => e
          FileUtils.rm_f(temp_file) if File.exist?(temp_file)
          raise Dotsync::PermissionError, "Permission denied: #{e.message}"
        rescue Errno::ENOSPC => e
          FileUtils.rm_f(temp_file) if File.exist?(temp_file)
          raise Dotsync::DiskFullError, "Disk full: #{e.message}"
        rescue StandardError => e
          FileUtils.rm_f(temp_file) if File.exist?(temp_file)
          raise Dotsync::FileTransferError, "Transfer failed: #{e.message}"
        end
      end

      def transfer_folder(folder_src, folder_dest)
        FileUtils.mkdir_p(folder_dest)

        # `Dir.glob("#{folder_src}/*")` retrieves only the immediate contents
        # (files and directories) within the specified directory (`folder_src`),
        # without descending into subdirectories.

        Dir.glob("#{folder_src}/*", File::FNM_DOTMATCH).each do |path|
          next if [".", ".."].include?(File.basename(path))

          full_path = File.expand_path(path)
          # puts full_path
          # require 'debug'; binding.b if full_path.include?("file6.txt")
          # require 'debug'; binding.b if full_path.include?("sub2folder2")
          next unless mapping.bidirectional_include?(full_path)
          next if mapping.ignore?(full_path)

          target = File.join(folder_dest, File.basename(path))
          if File.symlink?(full_path)
            transfer_symlink(full_path, target)
          elsif File.file?(full_path)
            transfer_file(full_path, target)
          elsif File.directory?(full_path)
            transfer_folder(full_path, target)
          end
        end
      end

      def transfer_symlink(symlink_src, symlink_dest)
        # Check if we're trying to overwrite a regular file or directory with a symlink
        if File.exist?(symlink_dest) && !File.symlink?(symlink_dest)
          if File.directory?(symlink_dest)
            raise Dotsync::TypeConflictError, "Cannot overwrite directory '#{symlink_dest}' with symlink '#{symlink_src}'"
          end
        end

        FileUtils.mkdir_p(File.dirname(symlink_dest))

        # Get the target the symlink points to
        link_target = File.readlink(symlink_src)

        begin
          # Remove existing symlink if present
          FileUtils.rm(symlink_dest) if File.exist?(symlink_dest) || File.symlink?(symlink_dest)

          # Create the new symlink
          File.symlink(link_target, symlink_dest)
        rescue Errno::EACCES, Errno::EPERM => e
          raise Dotsync::PermissionError, "Permission denied creating symlink: #{e.message}"
        rescue StandardError => e
          raise Dotsync::SymlinkError, "Failed to create symlink: #{e.message}"
        end
      end

      def cleanup_folder(target_dir)
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
          if @mapping.ignore?(abs_path)
            Find.prune if File.directory?(path)
            next
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
