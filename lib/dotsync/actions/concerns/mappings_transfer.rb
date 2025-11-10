# frozen_string_literal: true

module Dotsync
  module MappingsTransfer
    include Dotsync::PathUtils

    MAPPINGS_LEGEND = [
      [Icons.force, "The source will overwrite the destination"],
      [Icons.only, "Paths designated explicitly as source only"],
      [Icons.ignore, "Paths configured to be ignored in the destination"],
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
      table = Terminal::Table.new(rows: rows)
      logger.log(table)
      logger.log("")
    end

    def show_mappings_legend
      info("Mappings Legend:", icon: :legend)
      table = Terminal::Table.new(rows: MAPPINGS_LEGEND)
      logger.log(table)
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
      table = Terminal::Table.new(headings: ["Flags", "Source", "Destination"], rows: rows)
      logger.log(table)
      logger.log("")
    end

    def show_differences_legend
      info("Differences Legend:", icon: :legend)
      table = Terminal::Table.new(rows: DIFFERENCES_LEGEND)
      logger.log(table)
      logger.log("")
    end

    def show_differences
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
    end

    def transfer_mappings
      valid_mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      rescue Dotsync::PermissionError => e
        logger.error("Permission denied: #{e.message}")
        logger.info("Try: chmod +w <path> or check file permissions")
      rescue Dotsync::DiskFullError => e
        logger.error("Disk full: #{e.message}")
        logger.info("Free up disk space and try again")
      rescue Dotsync::SymlinkError => e
        logger.error("Symlink error: #{e.message}")
        logger.info("Check that symlink target exists and is accessible")
      rescue Dotsync::TypeConflictError => e
        logger.error("Type conflict: #{e.message}")
        logger.info("Cannot overwrite directory with file or vice versa")
      rescue Dotsync::FileTransferError => e
        logger.error("File transfer failed: #{e.message}")
      end
    end

    private
      def differs
        @differs ||= valid_mappings.map do |mapping|
          Dotsync::DirectoryDiffer.new(mapping).diff
        end
      end

      def has_differences?
        differs.any? { |differ| differ.any? }
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
  end
end
