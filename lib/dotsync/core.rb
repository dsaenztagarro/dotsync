# frozen_string_literal: true

# Core dependencies needed by all actions
require "fileutils"
require "logger"
require "forwardable"
require "ostruct"
require "find"

# Base classes and utilities
require_relative "errors"
require_relative "icons"
require_relative "colors"
require_relative "version"

# Config Concerns (loaded early as they're used by other modules)
require_relative "config/concerns/xdg_base_directory"

# Utils (common utilities)
require_relative "utils/path_utils"
require_relative "utils/logger"
require_relative "utils/version_checker"

# Runner
require_relative "runner"

module Dotsync
  class << self
    attr_writer :config_path

    def config_path
      @config_path ||= ENV["DOTSYNC_CONFIG"] || "~/.config/dotsync.toml"
    end
  end
end
