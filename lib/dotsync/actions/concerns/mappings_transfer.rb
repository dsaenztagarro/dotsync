# frozen_string_literal: true

module Dotsync
  module MappingsTransfer
    extend Forwardable # def_delegator

    def_delegator :@config, :mappings

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
      if diffs.any?
        info("Diff:", icon: :diff)
        diffs.flat_map(&:additions).sort.each do |path|
          logger.log("  #{path}", color: Dotsync::Colors.diff_additions)
        end
        diffs.flat_map(&:modifications).sort.each do |path|
          logger.log("  #{path}", color: Dotsync::Colors.diff_modifications)
        end
        diffs.flat_map(&:removals).sort.each do |path|
          logger.log("  #{path}", color: Dotsync::Colors.diff_removals)
        end
      end
    end

    def transfer_mappings
      valid_mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end
    end

    def valid_mappings
      mappings.select(&:valid?)
    end
  end
end
