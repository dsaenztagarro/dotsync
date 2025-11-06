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
        removals = []

        Find.find(mapping_src) do |src_path|
          rel_path = src_path.sub(/^#{Regexp.escape(mapping_src)}\/?/, "")

          unless @mapping.include?(src_path)
            Find.prune
            next
          end

          dest_path = File.join(mapping_dest, rel_path)

          if !File.exist?(dest_path)
            additions << rel_path
          elsif File.file?(src_path) && File.file?(dest_path)
            if File.size(src_path) != File.size(dest_path)
              modifications << rel_path
            end
          end
        end

        if force?
          Find.find(mapping_dest) do |dest_path|
            rel_path = dest_path.sub(/^#{Regexp.escape(mapping_dest)}\/?/, "")
            next if rel_path.empty?

            src_path = File.join(mapping_src, rel_path)

            if !File.exist?(src_path)
              removals << rel_path
            end
          end
        end

        additions = relative_to_absolute(filter_ignores(additions), mapping_original_dest)
        modifications = relative_to_absolute(filter_ignores(modifications), mapping_original_dest)
        removals = relative_to_absolute(filter_ignores(removals), mapping_original_src)

        Dotsync::Diff.new(additions: additions, modifications: modifications, removals: removals)
      end

      def diff_mapping_files
        Dotsync::Diff.new.tap do |diff|
          if @mapping.file_present_in_src_only?
            diff.additions << @mapping.original_dest
          elsif @mapping.file_changed?
            diff.modifications << @mapping.original_dest
          end
        end
      end

      def filter_ignores(all_paths)
        return all_paths unless ignores.any?
        all_paths.reject do |path|
          ignores.any? do |ignore|
            path == ignore || path.start_with?("#{ignore}/")
          end
        end
      end
  end
end
