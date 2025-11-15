# frozen_string_literal: true

# Setup only needs minimal dependencies
require "toml-rb"
require "fileutils"

# Load only what's needed
require_relative "../version"
require_relative "../utils/logger"
require_relative "../runner"

module Dotsync
  class << self
    attr_writer :config_path

    def config_path
      @config_path ||= ENV["DOTSYNC_CONFIG"] || "~/.config/dotsync.toml"
    end
  end
end
