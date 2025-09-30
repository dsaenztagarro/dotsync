module Dotsync
  class WatchActionConfig < BaseConfig
    def watched_paths
      section["paths"]
    end

    def output_directory
      section["output_dir"]
    end

    private

      SECTION_NAME = "watch"

      def section_name
        SECTION_NAME
      end

      def validate!
        validate_section_present!
        validate_key_present! "paths"
        validate_key_present! "output_dir"

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

        output_dir = File.expand_path(section["output_dir"])

        unless Dir.exist?(output_dir)
          raise_error "[watch] section key 'output_dir' contains invalid directory"
        end
      end
  end
end
