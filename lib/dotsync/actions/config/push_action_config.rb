module Dotsync
  class PushActionConfig < BaseConfig
    def mappings
      mappings_list = section["mappings"]
      Array(mappings_list).map do |mapping|
        {
          src: File.expand_path(mapping["src"]),
          dest: File.expand_path(mapping["dest"])
        }
      end
    end

    def force
      section["force"]
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
