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
  # For push: local → remote (src=local, dest=remote)
  # For pull: remote → local (src=remote, dest=local)
  module SyncMappings
    SYNC_SECTION = "sync"

    def sync_mappings_for_push
      convert_sync_mappings(direction: :push)
    end

    def sync_mappings_for_pull
      convert_sync_mappings(direction: :pull)
    end

    private

    def sync_section
      @config[SYNC_SECTION]
    end

    def sync_mappings_raw
      return [] unless sync_section
      Array(sync_section)
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

    def validate_sync_mappings!
      return unless sync_section

      sync_mappings_raw.each_with_index do |mapping, index|
        unless mapping.is_a?(Hash) && mapping.key?("local") && mapping.key?("remote")
          raise Dotsync::ConfigError,
            "Configuration error in sync mapping ##{index + 1}: Each sync mapping must have 'local' and 'remote' keys."
        end
      end
    end
  end
end
