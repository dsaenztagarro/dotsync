# frozen_string_literal: true

module Dotsync
  module Icons
    # Log level icons
    INFO = " "
    ERROR = " "

    # Configuration icon
    CONFIG = " "

    # Default MappingEntry icons
    DEFAULT_FORCE = "󰁪 "
    DEFAULT_IGNORE = "󰈉 "
    DEFAULT_INVALID = "󱏏 "

    # Action icons
    PULL = " "
    PUSH = " "
    WATCH = "󰛐 "

    # TODO: review icons needed
    CONSOLE = "󰆍 "
    LISTEN = " "
    SOURCE = " " #  "
    DEST = " " # " "
    BELL = " "
    COPY = " "
    SKIP = " "
    DONE = " "
    BACKUP = " "

    @custom_icons = {}

    def self.load_custom_icons(config)
      @custom_icons = {
        force: config.dig("icons", "force") || DEFAULT_FORCE,
        ignore: config.dig("icons", "ignore") || DEFAULT_IGNORE,
        invalid: config.dig("icons", "invalid") || DEFAULT_INVALID
      }
    end

    def self.force
      @custom_icons[:force] || DEFAULT_FORCE
    end

    def self.ignore
      @custom_icons[:ignore] || DEFAULT_IGNORE
    end

    def self.invalid
      @custom_icons[:invalid] || DEFAULT_INVALID
    end

    # https://www.nerdfonts.com
    MAPPINGS = {
      info: INFO,
      error: ERROR,
      config: CONFIG,
      force: -> { force },
      ignore: -> { ignore },
      pull: PULL,
      push: PUSH,
      watch: WATCH,
      console: CONSOLE,
      listen: LISTEN,
      source: SOURCE,
      dest: DEST,
      bell: BELL,
      copy: COPY,
      skip: SKIP,
      done: DONE,
      backup: BACKUP
    }
  end
end
