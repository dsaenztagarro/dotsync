module Dotsync
  class PullActionConfig < BaseConfig
    def src
      File.expand_path(section["src"])
    end

    def dest
      File.expand_path(section["dest"])
    end

    def backups_root
      File.expand_path(section["backups_root"])
    end

    def excluded_paths
      section["excluded_paths"].to_a.map { |path| File.join(src, path) }
    end

    private

      SECTION_NAME = "pull"

      def section_name
        SECTION_NAME
      end

      def validate!
        validate_section_present!
        validate_key_present! "src"
        validate_key_present! "dest"
        validate_key_present! "backups_root"
      end
  end
end
