# frozen_string_literal: true

module Dotsync
  module MappingsTransfer
    include Dotsync::PathUtils

    LEGEND = [
      [Dotsync::Icons.force, "The source will overwrite the destination"],
      [Dotsync::Icons.ignore, "Paths configured to be ignored in the destination"],
      [Dotsync::Icons.invalid, "Invalid paths detected in the source or destination"]
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
      info("Legend:", icon: :legend)
      table = Terminal::Table.new(rows: LEGEND)
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

    def show_changes
      diffs = valid_mappings.map do |mapping|
        Dotsync::DirectoryDiffer.new(mapping).diff
      end
      has_diff = false
      info("Diff:", icon: :diff)
      diffs.flat_map(&:additions).sort.each do |path|
        logger.log("  #{path}", color: Dotsync::Colors.diff_additions)
        has_diff = true
      end
      diffs.flat_map(&:modifications).sort.each do |path|
        logger.log("  #{path}", color: Dotsync::Colors.diff_modifications)
        has_diff = true
      end
      diffs.flat_map(&:removals).sort.each do |path|
        logger.log("  #{path}", color: Dotsync::Colors.diff_removals)
        has_diff = true
      end
      logger.log("  No differences") unless has_diff
    end

    def transfer_mappings
      valid_mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end
    end

    private
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
