# Libs dependencies
require 'fileutils'
require 'listen'
require 'toml-rb'
require 'logger'
require 'forwardable' # Ruby standard library
require 'ostruct'

# Concerns
require_relative "dotsync/configurable"

# Utils
require_relative 'dotsync/logger'

# Main classes
require_relative "dotsync/sync"
require_relative "dotsync/watch"

require_relative "dotsync/version"

module Dotsync
  class Error < StandardError; end
end
