# frozen_string_literal: true

module Dotsync
  module MappingsTransfer
    extend Forwardable # def_delegator

    def_delegator :@config, :mappings

    def show_env_vars
      env_vars = mappings_env_vars
      return unless env_vars.any?

      info("Environment variables:", icon: :env_vars)
      env_vars.each do |env_var|
        logger.log("  #{env_var}: #{ENV[env_var]}")
      end
    end

    def show_mappings
      info("Mappings:", icon: :config)

      mappings.each do |mapping|
        logger.log("  #{mapping}")
      end
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
