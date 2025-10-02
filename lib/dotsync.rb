# Libs dependencies
require 'fileutils'
require 'listen'
require 'toml-rb'
require 'logger'
require 'forwardable' # Ruby standard library
require 'ostruct'

# Errors
require_relative "dotsync/errors"

# Concerns
require_relative "dotsync/configurable"

# Utils
require_relative 'dotsync/logger'

# Actions
require_relative "dotsync/actions/config/base_config"
require_relative "dotsync/actions/config/watch_action_config"
require_relative "dotsync/actions/config/pull_action_config"
require_relative "dotsync/actions/base_action"
require_relative "dotsync/actions/pull_action"
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
