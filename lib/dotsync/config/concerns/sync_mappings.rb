# frozen_string_literal: true

module Dotsync
  # SyncMappings provides bidirectional mapping support.
  # It reads [[sync]] mappings and converts them to push or pull format.
  #
  # Sync mappings use `local` and `remote` keys instead of `src` and `dest`:
  #   [[sync]]
  #   local  = "$XDG_CONFIG_HOME/nvim"
  #   remote = "$XDG_CONFIG_HOME_MIRROR/nvim"
  #   force  = true
  #   ignore = ["lazy-lock.json"]
  #
  # XDG shorthand mappings automatically expand environment variables:
  #   [[sync.xdg_config]]
  #   path = "nvim"
  #   force = true
  #   # Expands to: local=$XDG_CONFIG_HOME/nvim, remote=$XDG_CONFIG_HOME_MIRROR/nvim
  #
  # Supported XDG shorthands:
  #   - sync.xdg_config: $XDG_CONFIG_HOME <-> $XDG_CONFIG_HOME_MIRROR
  #   - sync.xdg_data:   $XDG_DATA_HOME <-> $XDG_DATA_HOME_MIRROR
  #   - sync.xdg_cache:  $XDG_CACHE_HOME <-> $XDG_CACHE_HOME_MIRROR
  #   - sync.home:       $HOME <-> $HOME_MIRROR
  #
  # For push: local → remote (src=local, dest=remote)
  # For pull: remote → local (src=remote, dest=local)
  module SyncMappings
    SYNC_SECTION = "sync"

    # XDG shorthand type definitions
    XDG_SHORTHANDS = {
      "xdg_config" => { local: "$XDG_CONFIG_HOME", remote: "$XDG_CONFIG_HOME_MIRROR" },
      "xdg_data"   => { local: "$XDG_DATA_HOME",   remote: "$XDG_DATA_HOME_MIRROR" },
      "xdg_cache"  => { local: "$XDG_CACHE_HOME",  remote: "$XDG_CACHE_HOME_MIRROR" },
      "home"       => { local: "$HOME",            remote: "$HOME_MIRROR" }
    }.freeze

    def sync_mappings_for_push
      all_sync_mappings(:push)
    end

    def sync_mappings_for_pull
      all_sync_mappings(:pull)
    end

    private

    def all_sync_mappings(direction)
      convert_sync_mappings(direction: direction) + convert_xdg_shorthand_mappings(direction: direction)
    end

    def sync_section
      @config[SYNC_SECTION]
    end

    def sync_mappings_raw
      return [] unless sync_section.is_a?(Array)
      sync_section
    end

    def convert_sync_mappings(direction:)
      sync_mappings_raw.map do |mapping|
        converted = convert_sync_mapping(mapping, direction)
        Dotsync::Mapping.new(converted)
      end
    end

    def convert_sync_mapping(mapping, direction)
      local = mapping["local"]
      remote = mapping["remote"]

      base = case direction
             when :push
               { "src" => local, "dest" => remote }
             when :pull
               { "src" => remote, "dest" => local }
             end

      # Preserve other options
      base["force"] = mapping["force"] if mapping.key?("force")
      base["ignore"] = mapping["ignore"] if mapping.key?("ignore")
      base["only"] = mapping["only"] if mapping.key?("only")

      base
    end

    # XDG shorthand processing
    def xdg_shorthand_mappings_raw
      return [] unless sync_section.is_a?(Hash)

      mappings = []
      XDG_SHORTHANDS.each_key do |shorthand_type|
        next unless sync_section.key?(shorthand_type)
        Array(sync_section[shorthand_type]).each do |mapping|
          mappings << { type: shorthand_type, mapping: mapping }
        end
      end
      mappings
    end

    def convert_xdg_shorthand_mappings(direction:)
      xdg_shorthand_mappings_raw.map do |entry|
        converted = convert_xdg_shorthand_mapping(entry[:type], entry[:mapping], direction)
        Dotsync::Mapping.new(converted)
      end
    end

    def convert_xdg_shorthand_mapping(shorthand_type, mapping, direction)
      xdg_def = XDG_SHORTHANDS[shorthand_type]
      path = mapping["path"]

      local = path ? File.join(xdg_def[:local], path) : xdg_def[:local]
      remote = path ? File.join(xdg_def[:remote], path) : xdg_def[:remote]

      base = case direction
             when :push
               { "src" => local, "dest" => remote }
             when :pull
               { "src" => remote, "dest" => local }
             end

      # Preserve other options
      base["force"] = mapping["force"] if mapping.key?("force")
      base["ignore"] = mapping["ignore"] if mapping.key?("ignore")
      base["only"] = mapping["only"] if mapping.key?("only")

      base
    end

    def validate_sync_mappings!
      return unless sync_section

      # Validate array-style [[sync]] mappings
      if sync_section.is_a?(Array)
        sync_mappings_raw.each_with_index do |mapping, index|
          unless mapping.is_a?(Hash) && mapping.key?("local") && mapping.key?("remote")
            raise Dotsync::ConfigError,
              "Configuration error in sync mapping ##{index + 1}: Each sync mapping must have 'local' and 'remote' keys."
          end
        end
      end

      # Validate XDG shorthand mappings
      validate_xdg_shorthand_mappings!
    end

    def validate_xdg_shorthand_mappings!
      return unless sync_section.is_a?(Hash)

      XDG_SHORTHANDS.each_key do |shorthand_type|
        next unless sync_section.key?(shorthand_type)
        Array(sync_section[shorthand_type]).each_with_index do |mapping, index|
          unless mapping.is_a?(Hash)
            raise Dotsync::ConfigError,
              "Configuration error in sync.#{shorthand_type} mapping ##{index + 1}: Each mapping must be a table."
          end
        end
      end
    end
  end
end
