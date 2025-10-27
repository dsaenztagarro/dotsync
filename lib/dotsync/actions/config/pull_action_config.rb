# frozen_string_literal: true

module Dotsync
  class PullActionConfig < BaseConfig
    include XDGBaseDirectorySpec

    def mappings
      mappings_list = section["mappings"]
      Array(mappings_list).map { |mapping| Dotsync::MappingEntry.new(mapping) }
    end

    def backups_root
      File.join(xdg_data_home, "dotsync", "backups")
    end

    private
      SECTION_NAME = "pull"

      def section_name
        SECTION_NAME
      end

      def validate!
        validate_section_present!
        validate_key_present! "mappings"

        Array(section["mappings"]).each_with_index do |mapping, index|
          unless mapping.is_a?(Hash) && mapping.key?("src") && mapping.key?("dest")
            raise "Configuration error in mapping ##{index + 1}: Each mapping must have 'src' and 'dest' keys."
          end
        end
      end
  end
end
