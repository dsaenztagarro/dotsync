# Usage:
# differ = DirectoryDiffer.new("/path/to/src", "/path/to/dest")
# differences = differ.diff
class DirectoryDiffer
  attr_reader :src, :dest

  def initialize(src, dest)
    @src = File.expand_path(src)
    @dest = File.expand_path(dest)
  end

  def diff
    diffs = collect_src_diffs + collect_dest_diffs
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
          if File.size(src_path) != File.size(dest_path) ||
             File.mtime(src_path) != File.mtime(dest_path)
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
