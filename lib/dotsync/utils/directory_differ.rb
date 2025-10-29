# frozen_string_literal: true

module Dotsync
  # Usage:
  # differ = DirectoryDiffer.new("/path/to/src", "/path/to/dest")
  # differences = differ.diff
  class DirectoryDiffer
    extend Forwardable

    attr_reader :src, :dest

    def_delegator @mapping, :original_src
    def_delegator @mapping, :original_dest

    # Initializes a new DirectoryDiffer.
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
      @ignores = mapping.original_ignores || []
    end

    def diff
      additions = []
      modifications = []
      removals = []

      Find.find(src) do |src_path|
        rel_path = src_path.sub(/^#{Regexp.escape(src)}\/?/, "")
        next if rel_path.empty?

        dest_path = File.join(dest, rel_path)

        if !File.exist?(dest_path)
          additions << rel_path
        elsif File.file?(src_path) && File.file?(dest_path)
          if File.size(src_path) != File.size(dest_path)
            modifications << rel_path
          end
        end
      end

      if @force
        Find.find(dest) do |dest_path|
          rel_path = dest_path.sub(/^#{Regexp.escape(dest)}\/?/, "")
          next if rel_path.empty?

          src_path = File.join(src, rel_path)

          if !File.exist?(src_path)
            removals << rel_path
          end
        end
      end

      if @ignores.any?
        additions = filter_paths(additions, @ignores)
        modifications = filter_paths(modifications, @ignores)
        removals = filter_paths(removals, @ignores)
      end

      additions.map! { |rel_path| File.join(@mapping.original_dest, rel_path) }
      modifications.map! { |rel_path| File.join(@mapping.original_dest, rel_path) }
      removals.map! { |rel_path| File.join(@mapping.original_dest, rel_path) }

      Dotsync::Diff.new(additions: additions, modifications: modifications, removals: removals)
    end

    private
      def collect_src_diffs
        diffs = []
        Find.find(src) do |src_path|
          rel_path = src_path.sub(/^#{Regexp.escape(src)}\/?/, "")
          next if rel_path.empty?

          dest_path = File.join(dest, rel_path)

          if !File.exist?(dest_path)
            diffs << rel_path
          elsif File.directory?(src_path) && !File.directory?(dest_path)
            diffs << rel_path
          elsif File.file?(src_path) && !File.file?(dest_path)
            diffs << rel_path
          elsif File.file?(src_path) && File.file?(dest_path)
            if File.size(src_path) != File.size(dest_path)
              diffs << rel_path
            end
          end
        end
        diffs
      end

      def collect_dest_diffs
        diffs = []
        Find.find(dest) do |dest_path|
          rel_path = dest_path.sub(/^#{Regexp.escape(dest)}\/?/, "")
          next if rel_path.empty?
          src_path = File.join(src, rel_path)
          if !File.exist?(src_path)
            diffs << rel_path
          end
        end
        diffs
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
