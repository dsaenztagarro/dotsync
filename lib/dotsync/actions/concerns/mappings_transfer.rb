# frozen_string_literal: true

require "find"

module Dotsync
  # MappingsTransfer provides shared functionality for push/pull actions.
  #
  # == Performance Optimizations
  #
  # This module uses parallel execution for two key operations:
  #
  # 1. **Parallel diff computation** (see #differs)
  #    Each mapping's diff is computed in a separate thread. Since mappings are
  #    independent (different src/dest paths), this overlaps I/O and CPU work.
  #
  # 2. **Parallel file transfers** (see #transfer_mappings)
  #    File transfers for each mapping run concurrently. This is especially
  #    beneficial for many small files where I/O latency dominates.
  #
  # Error handling is thread-safe: errors are collected in a mutex-protected
  # array and reported after all parallel operations complete.
  #
  module MappingsTransfer
    include Dotsync::PathUtils

    MAPPINGS_LEGEND = [
      [Icons.force, "The source will overwrite the destination"],
      [Icons.only, "Filtered by 'only' whitelist"],
      [Icons.ignore, "Filtered by 'ignore' blacklist"],
      [Icons.hook, "Post-sync hooks configured"],
      [Icons.invalid, "Invalid paths detected in the source or destination"]
    ]

    DIFFERENCES_LEGEND = [
      [Icons.diff_created, "Created/added file"],
      [Icons.diff_updated, "Updated/modified file"],
      [Icons.diff_removed, "Removed/deleted file"]
    ]

    extend Forwardable # def_delegator

    def_delegator :@config, :mappings

    def show_env_vars
      env_vars = mappings_env_vars
      return unless env_vars.any?

      info("Environment variables:", icon: :env_vars)

      rows = env_vars.map { |env_var| [env_var, ENV[env_var]] }.sort_by(&:first)
      logger.log(Dotsync::TableRenderer.new(rows: rows).render)
      logger.log("")
    end

    def show_mappings_legend
      info("Mappings Legend:", icon: :legend)
      logger.log(Dotsync::TableRenderer.new(rows: MAPPINGS_LEGEND).render)
      logger.log("")
    end

    def show_mappings
      info("Mappings:", icon: :config)

      rows = mappings.map do |mapping|
        [
          mapping.icons,
          colorize_env_vars(mapping.original_src),
          colorize_env_vars(mapping.original_dest)
        ]
      end
      logger.log(Dotsync::TableRenderer.new(headings: ["Flags", "Source", "Destination"], rows: rows).render)
      logger.log("")
    end

    def show_differences_legend
      info("Differences Legend:", icon: :legend)
      logger.log(Dotsync::TableRenderer.new(rows: DIFFERENCES_LEGEND).render)
      logger.log("")
    end

    def show_differences(diff_content: false)
      info("Differences:", icon: :diff)
      differs.flat_map(&:additions).sort.each do |path|
        logger.log("#{Icons.diff_created}#{path}", color: Colors.diff_additions)
      end
      differs.flat_map(&:modifications).sort.each do |path|
        logger.log("#{Icons.diff_updated}#{path}", color: Colors.diff_modifications)
      end
      differs.flat_map(&:removals).sort.each do |path|
        logger.log("#{Icons.diff_removed}#{path}", color: Colors.diff_removals)
      end
      logger.log("  No differences") unless has_differences?
      logger.log("")

      show_content_diffs if diff_content && has_modifications?
    end

    def show_content_diffs
      info("Content Differences:", icon: :diff)
      modification_pairs.each do |pair|
        Dotsync::ContentDiff.new(pair[:src], pair[:dest], logger).display
      end
    end

    # Transfers all valid mappings from source to destination.
    #
    # OPTIMIZATION: Parallel execution
    # Mappings are transferred concurrently using Dotsync::Parallel.
    # Each mapping operates on independent paths, so parallel execution is safe.
    # Errors are collected thread-safely and reported after all transfers complete.
    def transfer_mappings
      errors = []
      mutex = Mutex.new

      # Process mappings in parallel - each mapping is independent
      Dotsync::Parallel.each(valid_mappings) do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      rescue Dotsync::PermissionError => e
        mutex.synchronize { errors << ["Permission denied: #{e.message}", "Try: chmod +w <path> or check file permissions"] }
      rescue Dotsync::DiskFullError => e
        mutex.synchronize { errors << ["Disk full: #{e.message}", "Free up disk space and try again"] }
      rescue Dotsync::SymlinkError => e
        mutex.synchronize { errors << ["Symlink error: #{e.message}", "Check that symlink target exists and is accessible"] }
      rescue Dotsync::TypeConflictError => e
        mutex.synchronize { errors << ["Type conflict: #{e.message}", "Cannot overwrite directory with file or vice versa"] }
      rescue Dotsync::FileTransferError => e
        mutex.synchronize { errors << ["File transfer failed: #{e.message}", nil] }
      end

      # Report all errors after parallel execution
      errors.each do |error_msg, info_msg|
        logger.error(error_msg)
        logger.info(info_msg) if info_msg
      end
    end

    def execute_hooks(force: false)
      valid_mappings.each_with_index do |mapping, idx|
        next unless mapping.has_hooks?

        differ = differs[idx]
        changed_files = differ.additions + differ.modifications
        if changed_files.empty?
          next unless force

          changed_files = all_dest_files(mapping)
          next if changed_files.empty?
        end

        runner = Dotsync::HookRunner.new(mapping: mapping, changed_files: changed_files, logger: logger)
        runner.execute
      end
    end

    def show_hooks_preview(force: false)
      hooks_to_run = []

      valid_mappings.each_with_index do |mapping, idx|
        next unless mapping.has_hooks?

        differ = differs[idx]
        changed_files = differ.additions + differ.modifications
        if changed_files.empty?
          next unless force

          changed_files = all_dest_files(mapping)
          next if changed_files.empty?
        end

        runner = Dotsync::HookRunner.new(mapping: mapping, changed_files: changed_files, logger: logger)
        hooks_to_run.concat(runner.preview)
      end

      return if hooks_to_run.empty?

      info("Hooks to run:", icon: :hook)
      hooks_to_run.each do |command|
        logger.log("  #{command}")
      end
      logger.log("")
    end

    private
      # Computes diffs for all valid mappings.
      #
      # OPTIMIZATION: Parallel diff computation
      # Each mapping's diff is computed in parallel using Dotsync::Parallel.map.
      # Results are memoized and returned in the same order as valid_mappings.
      # This overlaps I/O operations across mappings, reducing total wall time.
      def differs
        @differs ||= Dotsync::Parallel.map(valid_mappings) do |mapping|
          Dotsync::DirectoryDiffer.new(mapping).diff
        end
      end

      def has_differences?
        differs.any? { |differ| differ.any? }
      end

      def has_modifications?
        differs.any? { |differ| differ.modifications.any? }
      end

      def modification_pairs
        differs.flat_map(&:modification_pairs)
      end

      def confirm_action
        total_changes = differs.sum { |diff| diff.additions.size + diff.modifications.size + diff.removals.size }
        logger.log("")
        logger.info("About to modify #{total_changes} file(s).", icon: :warning)
        print "Continue? [y/N] "
        response = $stdin.gets
        response && response.strip.downcase == "y"
      end

      def mappings_env_vars
        paths = mappings.flat_map do |mapping|
          [mapping.original_src, mapping.original_dest]
        end

        paths.flat_map { |path| extract_env_vars(path) }.uniq
      end

      def valid_mappings
        mappings.select(&:valid?)
      end

      def all_dest_files(mapping)
        if File.directory?(mapping.dest)
          files = []
          Find.find(mapping.dest) do |path|
            next if File.directory?(path)

            files << path
          end
          files
        elsif File.file?(mapping.dest)
          [mapping.dest]
        else
          []
        end
      end
  end
end
