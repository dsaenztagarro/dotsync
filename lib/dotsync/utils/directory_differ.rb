module Dotsync
  # Usage:
  # differ = DirectoryDiffer.new("/path/to/src", "/path/to/dest")
  # differences = differ.diff
  class DirectoryDiffer
    attr_reader :src, :dest

    # Initializes a new DirectoryDiffer.
    #
    # @param mapping [Dotsync::Mapping] the mapping object containing source, destination, force, and ignore details
    # @option mapping [String] :src the source directory path
    # @option mapping [String] :dest the destination directory path
    # @option mapping [Boolean] :force? optional flag to force actions
    # @option mapping [Array<String>] :ignores optional list of files/directories to ignore
    def initialize(mapping)
      @src = mapping.src
      @dest = mapping.dest
      @force = mapping.force?
      @ignores = mapping.ignores || []
    end

    def diff
      diffs = collect_src_diffs
      diffs += collect_dest_diffs if @force
      diffs -= @ignores
      diffs.uniq
    end

    private

      def collect_src_diffs
        diffs = []
        Find.find(src) do |src_path|
          rel_path = src_path.sub(/^#{Regexp.escape(src)}\/?/, '')
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
          rel_path = dest_path.sub(/^#{Regexp.escape(dest)}\/?/, '')
          next if rel_path.empty?
          src_path = File.join(src, rel_path)
          if !File.exist?(src_path)
            diffs << rel_path
          end
        end
        diffs
      end
  end
end
