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
