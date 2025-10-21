module Dotsync
  class PullActionConfig < BaseConfig
    include XDGBaseDirectorySpec

    def mappings
      mappings_list = section["mappings"]
      Array(mappings_list).map { |mapping| Dotsync::MappingEntry.new(mapping) }
    end

    def force
      section["force"]
    end

    def backups_root
      File.join(xdg_data_home, "dotsync", "backups")
    end

    def ignore
      section["ignore"].to_a.map { |path| File.join(src, path) }
    end

    private

      SECTION_NAME = "pull"

      def section_name
        SECTION_NAME
      end

      def validate!
        validate_section_present!
        validate_key_present! "mappings"
        validate_key_present! "force"
      end
  end
end
