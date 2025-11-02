# frozen_string_literal: true

module Dotsync
  module PathUtils
    ENV_VARS_COLOR = 104

    def expand_env_vars(path)
      path.gsub(/\$(\w+)/) { ENV[$1] }
    end

    def extract_env_vars(path)
      path.scan(/\$(\w+)/).flatten
    end

    def colorize_env_vars(path)
      path.gsub(/\$(\w+)/) { "\e[38;5;#{ENV_VARS_COLOR}m$#{$1}\e[0m" }
    end

    # Converts an array of relative paths to absolute paths based on a specified base path
    # @param [Array<String>] paths The array of relative paths
    # @param [String] base_path The base absolute path to resolve relative paths
    # @return [Array<String>] The array of absolute paths
    def relative_to_absolute(paths, base_path)
      paths.map { |path| File.join(base_path, path) }
    end

    # Translates /tmp paths to /private/tmp paths on macOS
    # Retains other paths as-is
    # @param [String] path The input path to translate
    # @return [String] The translated path
    def translate_tmp_path(path)
      if path.start_with?("/tmp") && RUBY_PLATFORM.include?("darwin")
        path.sub("/tmp", "/private/tmp")
      else
        path
      end
    end

    # Sanitizes a given path by expanding it and translating /tmp to /private/tmp
    # @param [String] path The input path to sanitize
    # @return [String] The sanitized path
    def sanitize_path(path)
      translate_tmp_path(File.expand_path(expand_env_vars(path)))
    end
  end
end
