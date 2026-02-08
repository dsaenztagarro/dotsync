# frozen_string_literal: true

module Dotsync
  # Mapping represents a source-to-destination path pair for synchronization.
  #
  # A mapping defines what should be synced (src -> dest), with optional filters:
  # - `only`: whitelist of paths to include (everything else is excluded)
  # - `ignore`: blacklist of paths to exclude
  # - `force`: enable removal detection (find dest files not in src)
  #
  # == Path Matching Methods
  #
  # The class provides several methods for path filtering, each with specific use cases:
  #
  # - #include?(path): Returns true if path is inside an inclusion. Used for file filtering.
  # - #bidirectional_include?(path): Returns true if path is inside OR contains an inclusion.
  #   Used during directory traversal to allow descending into parent directories.
  # - #should_prune_directory?(path): Returns true if a directory subtree can be skipped entirely.
  #   This is a PERFORMANCE OPTIMIZATION for Find.prune - see DirectoryDiffer for details.
  #
  class Mapping
    include Dotsync::PathUtils

    attr_reader :original_src, :original_dest, :original_ignores, :original_only

    def initialize(attributes)
      @original_src = attributes["src"]
      @original_dest = attributes["dest"]
      @original_ignores = Array(attributes["ignore"])
      @original_only = Array(attributes["only"])
      @force = attributes["force"] || false
      @hooks = Array(attributes["hooks"])

      @sanitized_src, @sanitized_dest, @sanitized_ignores, @sanitized_only = process_paths(
        @original_src,
        @original_dest,
        @original_ignores,
        @original_only
      )
    end

    def src
      @sanitized_src
    end

    def dest
      @sanitized_dest
    end

    def ignores
      @sanitized_ignores
    end

    def inclusions
      @sanitized_only
    end

    def force?
      @force
    end

    attr_reader :hooks

    def has_hooks?
      @hooks.any?
    end

    def directories?
      File.directory?(src) && File.directory?(dest)
    end

    def files?
      files_present? || file_present_in_src_only?
    end

    def files_present?
      File.file?(src) && File.file?(dest)
    end

    def file_present_in_src_only?
      File.file?(src) && !File.exist?(dest) && File.directory?(File.dirname(dest))
    end

    def valid?
      return false unless paths_are_distinct?
      return false unless paths_not_nested?
      directories? || files? || file_present_in_src_only?
    end

    def file_changed?
      return false unless files_present?
      # Check size first for quick comparison
      return true if File.size(src) != File.size(dest)
      # If sizes match, compare content
      FileUtils.compare_file(src, dest) == false
    end

    def backup_possible?
      valid? && File.exist?(dest)
    end

    def backup_basename
      return unless valid?
      return File.dirname(dest) unless File.exist?(dest)
      File.basename(dest)
    end

    def icons
      msg = []
      msg << Icons.force if force?
      msg << Icons.only if has_inclusions?
      msg << Icons.ignore if has_ignores?
      msg << Icons.hook if has_hooks?
      msg << Icons.invalid unless valid?
      msg.join
    end

    def to_s
      msg = "#{decorated_src} → #{decorated_dest}"
      msg += " #{icons}" if icons != ""
      msg
    end

    def decorated_src
      colorize_env_vars(original_src)
    end

    def decorated_dest
      colorize_env_vars(original_dest)
    end

    def apply_to(path)
      relative_path = if Pathname.new(path).absolute?
        path.delete_prefix(File.join(src, "/"))
      else
        path
      end

      Dotsync::Mapping.new(
        "src" => File.join(@original_src, relative_path),
        "dest" => File.join(@original_dest, relative_path),
        "force" => @force,
        "only" => @only,
        "ignore" => @original_ignores
      )
    end

    def include?(path)
      return true unless has_inclusions?
      return true if path == src
      inclusions.any? { |inclusion| path_is_parent_or_same?(inclusion, path) }
    end

    def bidirectional_include?(path)
      return true unless has_inclusions?
      return true if path == src
      inclusions.any? { |inclusion| path_is_parent_or_same?(inclusion, path) || path_is_parent_or_same?(path, inclusion) }
    end

    def ignore?(path)
      ignores.any? { |ignore| path.start_with?(ignore) }
    end

    def skip?(path)
      ignore?(path) || !include?(path)
    end

    # Determines if a directory subtree can be entirely skipped during traversal.
    #
    # PERFORMANCE OPTIMIZATION: This method enables Find.prune in DirectoryDiffer.
    # When walking large destination directories (e.g., ~/.config with 8,686 files),
    # pruning irrelevant subtrees avoids visiting thousands of files that will never
    # match the `only` filter. This reduced scan time from 7.2s to 0.5s in benchmarks.
    #
    # A directory should be pruned if:
    # 1. It's ignored (in the ignore list), OR
    # 2. It has inclusions AND the path is neither:
    #    - Inside an inclusion (would be synced)
    #    - A parent of an inclusion (might contain synced files)
    #
    # @param path [String] Absolute path to check
    # @return [Boolean] true if the entire directory subtree can be skipped
    def should_prune_directory?(path)
      return true if ignore?(path)
      return false unless has_inclusions?
      !bidirectional_include?(path)
    end

    private
      def has_ignores?
        @original_ignores.any?
      end

      def has_inclusions?
        @original_only.any?
      end

      def process_paths(raw_src, raw_dest, raw_ignores, raw_only)
        sanitized_src = sanitize_path(raw_src)
        sanitized_dest = sanitize_path(raw_dest)
        sanitized_ignores = raw_ignores.flat_map do |path|
          [File.join(sanitized_src, path), File.join(sanitized_dest, path)]
        end
        sanitized_only = raw_only.flat_map do |path|
          [File.join(sanitized_src, path), File.join(sanitized_dest, path)]
        end
        [sanitized_src, sanitized_dest, sanitized_ignores, sanitized_only]
      end

      def paths_are_distinct?
        src != dest
      end

      def paths_not_nested?
        # Check if dest is inside src or vice versa
        return false if dest.start_with?("#{src}/")
        return false if src.start_with?("#{dest}/")
        true
      end
  end
end
