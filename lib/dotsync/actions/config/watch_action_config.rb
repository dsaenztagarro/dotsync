module Dotsync
  class WatchActionConfig < BaseConfig
    def src
      File.expand_path(section["src"])
    end

    def dest
      File.expand_path(section["dest"])
    end

    def watched_paths
      section["paths"]
    end

    private

      SECTION_NAME = "watch"

      def section_name
        SECTION_NAME
      end

      def validate!
        validate_section_present!
        validate_key_present! "src"
        validate_key_present! "dest"
        validate_key_present! "paths"

        paths = section["paths"]

        unless paths.is_a?(Array)
          raise_error "[watch] section key 'paths' must be a list"
        end

        if paths.empty?
          raise_error "[watch] section key 'paths' must not be empty"
        end

        unless paths.all? { |path| File.exist?(File.expand_path(path)) }
          raise_error "[watch] section key 'paths' contains invalid file paths; all listed files must exist"
        end

        dir = File.expand_path(section["dest"])

        unless Dir.exist?(dir)
          raise_error "[watch] section key 'dest' contains invalid directory"
        end
      end
  end
end
