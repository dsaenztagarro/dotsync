module Dotsync
  module PathUtils
    def expand_env_vars(path)
      path.gsub(/\$(\w+)/) { ENV[$1] }
    end

    # Translates /tmp paths to /private/tmp paths on macOS
    # Retains other paths as-is
    # @param [String] path The input path to translate
    # @return [String] The translated path
    def translate_tmp_path(path)
      expanded_path = File.expand_path(path)
      if expanded_path.start_with?('/tmp') && RUBY_PLATFORM.include?('darwin')
        expanded_path.sub('/tmp', '/private/tmp')
      else
        expanded_path
      end
    end

    # Sanitizes a given path by expanding it and translating /tmp to /private/tmp
    # @param [String] path The input path to sanitize
    # @return [String] The sanitized path
    def sanitize_path(path)
      path = expand_env_vars(path)
      path = translate_tmp_path(File.expand_path(path))
      path
    end
  end
end
