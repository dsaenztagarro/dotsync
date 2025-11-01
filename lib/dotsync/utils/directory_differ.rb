# frozen_string_literal: true

module Dotsync
  class DirectoryDiffer
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

        if ignores.any?
          additions = filter_paths(additions, ignores)
          modifications = filter_paths(modifications, ignores)
          removals = filter_paths(removals, ignores)
        end

        additions.map! { |rel_path| File.join(mapping_original_dest, rel_path) }
        modifications.map! { |rel_path| File.join(mapping_original_dest, rel_path) }
        removals.map! { |rel_path| File.join(mapping_original_src, rel_path) }

        Dotsync::Diff.new(additions: additions, modifications: modifications, removals: removals)
      end

      def diff_mapping_files
        Dotsync::Diff.new.tap do |diff|
          if !File.exist?(@mapping.dest)
            diff.additions << @mapping.original_dest
          else
            diff.modifications << @mapping.original_dest
          end
        end
      end

      def filter_paths(all_paths, ignore_paths)
        all_paths.reject do |path|
          ignore_paths.any? do |ignore|
            path == ignore || path.start_with?("#{ignore}/")
          end
        end
      end
  end
end
