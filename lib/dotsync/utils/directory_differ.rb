# frozen_string_literal: true

module Dotsync
  class DirectoryDiffer
    include Dotsync::PathUtils

    extend Forwardable

    # attr_reader :src, :dest

    def_delegator :@mapping, :src, :mapping_src
    def_delegator :@mapping, :dest, :mapping_dest
    def_delegator :@mapping, :original_src, :mapping_original_src
    def_delegator :@mapping, :original_dest, :mapping_original_dest
    def_delegator :@mapping, :force?, :force?
    def_delegator :@mapping, :original_ignores, :ignores

    def initialize(mapping)
      @mapping = mapping
    end

    def diff
      if @mapping.directories?
        diff_mapping_directories
      elsif @mapping.files?
        diff_mapping_files
      end
    end

    private
      def diff_mapping_directories
        additions = []
        modifications = []
        modification_pairs = []
        removals = []

        Find.find(mapping_src) do |src_path|
          rel_path = src_path.sub(/^#{Regexp.escape(mapping_src)}\/?/, "")

          unless @mapping.bidirectional_include?(src_path)
            Find.prune
            next
          end

          dest_path = File.join(mapping_dest, rel_path)

          if !File.exist?(dest_path)
            additions << rel_path
          elsif File.file?(src_path) && File.file?(dest_path)
            if files_differ?(src_path, dest_path)
              modifications << rel_path
              modification_pairs << { rel_path: rel_path, src: src_path, dest: dest_path }
            end
          end
        end

        if force?
          Find.find(mapping_dest) do |dest_path|
            rel_path = dest_path.sub(/^#{Regexp.escape(mapping_dest)}\/?/, "")
            next if rel_path.empty?

            src_path = File.join(mapping_src, rel_path)

            next if @mapping.skip?(src_path)

            if !File.exist?(src_path)
              removals << rel_path
            end
          end
        end

        filtered_modifications = filter_ignores(modifications)
        modification_pairs = modification_pairs.select { |pair| filtered_modifications.include?(pair[:rel_path]) }

        additions = relative_to_absolute(filter_ignores(additions), mapping_original_dest)
        modifications = relative_to_absolute(filtered_modifications, mapping_original_dest)
        removals = relative_to_absolute(filter_ignores(removals), mapping_original_dest)

        Dotsync::Diff.new(additions: additions, modifications: modifications, removals: removals, modification_pairs: modification_pairs)
      end

      def diff_mapping_files
        additions = []
        modifications = []
        modification_pairs = []

        if @mapping.file_present_in_src_only?
          additions << @mapping.original_dest
        elsif @mapping.file_changed?
          modifications << @mapping.original_dest
          modification_pairs << { rel_path: File.basename(@mapping.original_dest), src: @mapping.src, dest: @mapping.dest }
        end

        Dotsync::Diff.new(additions: additions, modifications: modifications, modification_pairs: modification_pairs)
      end

      def filter_ignores(all_paths)
        return all_paths unless ignores.any?
        all_paths.reject do |path|
          ignores.any? do |ignore|
            path == ignore || path.start_with?("#{ignore}/")
          end
        end
      end

      def files_differ?(src_path, dest_path)
        # First check size for quick comparison
        return true if File.size(src_path) != File.size(dest_path)

        # If sizes match, compare content
        FileUtils.compare_file(src_path, dest_path) == false
      end
  end
end
