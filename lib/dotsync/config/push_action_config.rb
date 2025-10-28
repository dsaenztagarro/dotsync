# frozen_string_literal: true

module Dotsync
  class PushActionConfig < BaseConfig
    def mappings
      mappings_list = section["mappings"]
      Array(mappings_list).map { |mapping| Dotsync::MappingEntry.new(mapping) }
    end

    private
      SECTION_NAME = "push"

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
