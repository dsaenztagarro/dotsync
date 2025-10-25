# Libs dependencies
require 'fileutils'
require 'listen'
require 'toml-rb'
require 'logger'
require 'forwardable' # Ruby standard library
require 'ostruct'

# Errors
require_relative "dotsync/errors"

# Utils
require_relative 'dotsync/icons'
require_relative 'dotsync/logger'
require_relative 'dotsync/file_transfer'
require_relative 'dotsync/path_utils'

# Config
require_relative "dotsync/actions/config/xdg_base_directory_spec"
require_relative "dotsync/actions/config/mapping_entry"
require_relative "dotsync/actions/config/base_config"
require_relative "dotsync/actions/config/pull_action_config"
require_relative "dotsync/actions/config/push_action_config"
require_relative "dotsync/actions/config/watch_action_config"

# Concerns
require_relative "dotsync/actions/concerns/mappings_transfer"

# Actions
require_relative "dotsync/actions/base_action"
require_relative "dotsync/actions/pull_action"
require_relative "dotsync/actions/push_action"
require_relative "dotsync/actions/watch_action"

require_relative 'dotsync/runner'

require_relative "dotsync/version"

module Dotsync
  class Error < StandardError; end

  class << self
    attr_writer :config_path

    def config_path
      @config_path ||= ENV['DOTSYNC_CONFIG'] || "~/.config/dotsync.toml"
    end
  end
end
