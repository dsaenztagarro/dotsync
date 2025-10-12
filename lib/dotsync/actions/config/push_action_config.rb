module Dotsync
  class PushActionConfig < BaseConfig
    def src
      File.expand_path(section["src"])
    end

    def dest
      File.expand_path(section["dest"])
    end

    def remove_dest
      section["remove_dest"]
    end

    def excluded_paths
      section["excluded_paths"]
    end

    private

      SECTION_NAME = "push"

      def section_name
        SECTION_NAME
      end

      def validate!
        validate_section_present!
        validate_key_present! "src"
        validate_key_present! "dest"
        validate_key_present! "remove_dest"
      end
  end
end
