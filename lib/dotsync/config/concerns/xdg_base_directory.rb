# frozen_string_literal: true

module Dotsync
  # https://specifications.freedesktop.org/basedir-spec/latest/
  module XDGBaseDirectory
    def xdg_data_home
      File.expand_path(ENV["XDG_DATA_HOME"] || "$HOME/.local/share")
    end

    def xdg_config_home
      File.expand_path(ENV["XDG_CONFIG_HOME"] || "$HOME/.config")
    end

    def xdg_cache_home
      File.expand_path(ENV["XDG_CACHE_HOME"] || "$HOME/.cache")
    end

    def xdg_bin_home
      File.expand_path(ENV["XDG_BIN_HOME"] || "$HOME/.local/bin")
    end
  end
end
