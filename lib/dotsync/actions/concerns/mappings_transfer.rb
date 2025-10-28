# frozen_string_literal: true

module Dotsync
  module MappingsTransfer
    extend Forwardable # def_delegator

    def_delegator :@config, :mappings

    def show_mappings
      info("Mappings:", icon: :config,)

      mappings.each do |mapping|
        logger.log("  #{mapping}")
      end
    end

    def transfer_mappings
      valid_mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end
    end

    def valid_mappings
      mappings.select(&:valid?)
    end

    private

      def diff_files_and_dirs(src, dest)
        diffs = []

        # Get all files and directories in the source
        Find.find(src) do |src_path|
          rel_path = src_path.sub(/^#{Regexp.escape(src)}\/?/, '')
          next if rel_path.empty? # skip the root itself

          dest_path = File.join(dest, rel_path)

          if !File.exist?(dest_path)
            diffs << rel_path
          elsif File.directory?(src_path) && !File.directory?(dest_path)
            diffs << rel_path
          elsif File.file?(src_path) && !File.file?(dest_path)
            diffs << rel_path
          elsif File.file?(src_path) && File.file?(dest_path)
            # Compare by size and mtime
            if File.size(src_path) != File.size(dest_path) ||
               File.mtime(src_path) != File.mtime(dest_path)
              diffs << rel_path
            end
          end
        end

        # Check for files and dirs in dest that don't exist in src
        Find.find(dest) do |dest_path|
          rel_path = dest_path.sub(/^#{Regexp.escape(dest)}\/?/, '')
          next if rel_path.empty?
          src_path = File.join(src, rel_path)
          if !File.exist?(src_path)
            diffs << rel_path
          end
        end

        diffs.uniq
      end
  end
end
