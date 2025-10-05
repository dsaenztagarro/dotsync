module Dotsync
  module PathUtils
    # Translates /tmp paths to /private/tmp paths on macOS
    # Retains other paths as-is
    # @param [String] path The input path to translate
    # @return [String] The translated path
    def translate_tmp_path(path)
      expanded_path = File.expand_path(path)
      if expanded_path.start_with?('/tmp')
        expanded_path.sub('/tmp', '/private/tmp')
      else
        expanded_path
      end
    end

    # Ensures the directory path ends with a trailing slash if the directory exists.
    # If the directory does not exist, the path is returned unchanged.
    #
    # @param [String] path The directory path to sanitize
    # @return [String] The sanitized directory path
    def sanitize_dir_path(path)
      Dir.exist?(path) ? File.join(path, "/") : path
    end

    # Sanitizes a given path by expanding it and translating /tmp to /private/tmp
    # @param [String] path The input path to sanitize
    # @return [String] The sanitized path
    def sanitize_path(path)
      path = translate_tmp_path(File.expand_path(path))
      path = sanitize_dir_path(path)
      path
    end
  end
end
