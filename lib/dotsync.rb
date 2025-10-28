# frozen_string_literal: true

# Libs dependencies
require "fileutils"
require "listen"
require "toml-rb"
require "logger"
require "forwardable" # Ruby standard library
require "ostruct"
require "find"

# Utils
require_relative "dotsync/utils/logger"
require_relative "dotsync/utils/file_transfer"
require_relative "dotsync/utils/directory_differ"
require_relative "dotsync/utils/path_utils"

# Models
require_relative "dotsync/models/mapping"
require_relative "dotsync/models/diff"

# Config
require_relative "dotsync/config/xdg_base_directory_spec"
require_relative "dotsync/config/base_config"
require_relative "dotsync/config/pull_action_config"
require_relative "dotsync/config/push_action_config"
require_relative "dotsync/config/watch_action_config"

# Actions Concerns
require_relative "dotsync/actions/concerns/mappings_transfer"

# Actions
require_relative "dotsync/actions/base_action"
require_relative "dotsync/actions/pull_action"
require_relative "dotsync/actions/push_action"
require_relative "dotsync/actions/watch_action"

# Base classes
require_relative "dotsync/errors"
require_relative "dotsync/icons"
require_relative "dotsync/colors"
require_relative "dotsync/runner"
require_relative "dotsync/version"

module Dotsync
  class << self
    attr_writer :config_path

    def config_path
      @config_path ||= ENV["DOTSYNC_CONFIG"] || "~/.config/dotsync.toml"
    end
  end
end
