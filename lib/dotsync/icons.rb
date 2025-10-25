module Dotsync
  module Icons
    # Log level icons
    INFO = " "
    ERROR = " "

    # Configuration icon
    CONFIG = " "

    # MappingEntry icons
    FORCE = "󰁪 "
    IGNORE = "󰈉 "
    INVALID = "󱏏 "

    # Action icons
    PULL = " "
    PUSH = " "
    WATCH = "󰛐 "

    # TODO: review iconds needed
    LISTEN = " "
    SOURCE = " " #  "
    DEST = " " # " "
    DELETE = " "
    BELL = " "
    COPY = " "
    SKIP = " "
    DONE = " "
    BACKUP = " "

    # https://www.nerdfonts.com
    MAPPINGS = {
      info: INFO,
      error: ERROR,
      config: CONFIG,
      force: FORCE,
      ignore: IGNORE,
      pull: PULL,
      push: PUSH,
      watch: WATCH,
      listen: LISTEN,
      source: SOURCE,
      dest: DEST,
      delete: DELETE,
      bell: BELL,
      copy: COPY,
      skip: SKIP,
      done: DONE,
      backup: BACKUP
    }
  end
end
