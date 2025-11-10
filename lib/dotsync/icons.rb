# frozen_string_literal: true

module Dotsync
  module Icons
    # Log level icons
    INFO = " "
    ERROR = " "

    # Configuration icon
    OPTIONS = " "
    ENV_VARS = " "
    LEGEND = " "
    CONFIG = " "
    DIFF = " "

    # Default Mappings Legend icons
    DEFAULT_FORCE = "󰁪 "
    DEFAULT_ONLY = " "
    DEFAULT_IGNORE = "󰈉 "
    DEFAULT_INVALID = "󱏏 "

    # Default Mappings Differences icons
    DEFAULT_DIFF_CREATED = " "
    DEFAULT_DIFF_UPDATED = " "
    DEFAULT_DIFF_REMOVED = " "

    # Action icons
    PULL = " "
    PUSH = " "
    WATCH = "󰛐 "

    CONSOLE = "󰆍 "
    # TODO: review icons needed
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
      config ||= {}
      @custom_icons = {
        # Mappings Legend
        force: config.dig("icons", "force") || DEFAULT_FORCE,
        only: config.dig("icons", "only") || DEFAULT_ONLY,
        ignore: config.dig("icons", "ignore") || DEFAULT_IGNORE,
        invalid: config.dig("icons", "invalid") || DEFAULT_INVALID,
        # Differences Legend
        diff_created: config.dig("icons", "diff_created") || DEFAULT_DIFF_CREATED,
        diff_updated: config.dig("icons", "diff_updated") || DEFAULT_DIFF_UPDATED,
        diff_removed: config.dig("icons", "diff_removed") || DEFAULT_DIFF_REMOVED,
      }
    end

    # Mappings Legend methods

    def self.force
      @custom_icons[:force] || DEFAULT_FORCE
    end

    def self.only
      @custom_icons[:only] || DEFAULT_ONLY
    end

    def self.ignore
      @custom_icons[:ignore] || DEFAULT_IGNORE
    end

    def self.invalid
      @custom_icons[:invalid] || DEFAULT_INVALID
    end

    # Differences Legend methods

    def self.diff_created
      @custom_icons[:diff_created] || DEFAULT_DIFF_CREATED
    end

    def self.diff_updated
      @custom_icons[:diff_updated] || DEFAULT_DIFF_UPDATED
    end

    def self.diff_removed
      @custom_icons[:diff_removed] || DEFAULT_DIFF_REMOVED
    end

    # https://www.nerdfonts.com
    MAPPINGS = {
      info: INFO,
      error: ERROR,
      env_vars: ENV_VARS,
      options: OPTIONS,
      legend: LEGEND,
      config: CONFIG,
      diff: DIFF,
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
