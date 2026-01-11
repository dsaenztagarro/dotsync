# frozen_string_literal: true

module Dotsync
  # SyncMappings provides bidirectional mapping support.
  # It reads [sync] section mappings and converts them to push or pull format.
  #
  # The [sync] section supports multiple sub-types:
  #
  # 1. Explicit mappings with [[sync.mappings]]:
  #    [[sync.mappings]]
  #    local  = "$XDG_CONFIG_HOME/nvim"
  #    remote = "$XDG_CONFIG_HOME_MIRROR/nvim"
  #    force  = true
  #    ignore = ["lazy-lock.json"]
  #
  # 2. XDG shorthand mappings that auto-expand environment variables:
  #    [[sync.xdg_config]]
  #    path = "nvim"
  #    force = true
  #    # Expands to: local=$XDG_CONFIG_HOME/nvim, remote=$XDG_CONFIG_HOME_MIRROR/nvim
  #
  # Supported shorthands:
  #   - sync.home:       $HOME <-> $HOME_MIRROR
  #   - sync.xdg_config: $XDG_CONFIG_HOME <-> $XDG_CONFIG_HOME_MIRROR
  #   - sync.xdg_data:   $XDG_DATA_HOME <-> $XDG_DATA_HOME_MIRROR
  #   - sync.xdg_cache:  $XDG_CACHE_HOME <-> $XDG_CACHE_HOME_MIRROR
  #   - sync.xdg_bin:    $XDG_BIN_HOME <-> $XDG_BIN_HOME_MIRROR
  #   - sync.mappings:   explicit local/remote mappings
  #
  # For push: local → remote (src=local, dest=remote)
  # For pull: remote → local (src=remote, dest=local)
  module SyncMappings
    SYNC_SECTION = "sync"
    MAPPINGS_KEY = "mappings"

    # Shorthand type definitions mapping to local/remote base paths
    SHORTHANDS = {
      "home"       => { local: "$HOME",            remote: "$HOME_MIRROR" },
      "xdg_config" => { local: "$XDG_CONFIG_HOME", remote: "$XDG_CONFIG_HOME_MIRROR" },
      "xdg_data"   => { local: "$XDG_DATA_HOME",   remote: "$XDG_DATA_HOME_MIRROR" },
      "xdg_cache"  => { local: "$XDG_CACHE_HOME",  remote: "$XDG_CACHE_HOME_MIRROR" },
      "xdg_bin"    => { local: "$XDG_BIN_HOME",    remote: "$XDG_BIN_HOME_MIRROR" }
    }.freeze

    def sync_mappings_for_push
      all_sync_mappings(:push)
    end

    def sync_mappings_for_pull
      all_sync_mappings(:pull)
    end

    def has_sync_mappings?
      return false unless sync_section.is_a?(Hash)

      explicit_mappings_raw.any? || shorthand_mappings_raw.any?
    end

    private
      def all_sync_mappings(direction)
        convert_explicit_mappings(direction: direction) + convert_shorthand_mappings(direction: direction)
      end

      def sync_section
        @config[SYNC_SECTION]
      end

      # Explicit [[sync.mappings]] with local/remote keys
      def explicit_mappings_raw
        return [] unless sync_section.is_a?(Hash)
        return [] unless sync_section.key?(MAPPINGS_KEY)

        Array(sync_section[MAPPINGS_KEY])
      end

      def convert_explicit_mappings(direction:)
        explicit_mappings_raw.map do |mapping|
          converted = convert_explicit_mapping(mapping, direction)
          Dotsync::Mapping.new(converted)
        end
      end

      def convert_explicit_mapping(mapping, direction)
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

      # Shorthand mappings: [[sync.home]], [[sync.xdg_config]], etc.
      def shorthand_mappings_raw
        return [] unless sync_section.is_a?(Hash)

        mappings = []
        SHORTHANDS.each_key do |shorthand_type|
          next unless sync_section.key?(shorthand_type)
          Array(sync_section[shorthand_type]).each do |mapping|
            mappings << { type: shorthand_type, mapping: mapping }
          end
        end
        mappings
      end

      def convert_shorthand_mappings(direction:)
        shorthand_mappings_raw.map do |entry|
          converted = convert_shorthand_mapping(entry[:type], entry[:mapping], direction)
          Dotsync::Mapping.new(converted)
        end
      end

      def convert_shorthand_mapping(shorthand_type, mapping, direction)
        shorthand_def = SHORTHANDS[shorthand_type]

        # Support both 'path' for single paths and 'only' for multiple paths
        path = mapping["path"]
        only = mapping["only"]

        local = build_path(shorthand_def[:local], path)
        remote = build_path(shorthand_def[:remote], path)

        base = case direction
               when :push
                 { "src" => local, "dest" => remote }
               when :pull
                 { "src" => remote, "dest" => local }
        end

        # Preserve other options
        base["force"] = mapping["force"] if mapping.key?("force")
        base["ignore"] = mapping["ignore"] if mapping.key?("ignore")
        base["only"] = only if only

        base
      end

      def build_path(base, path)
        path ? File.join(base, path) : base
      end

      def validate_sync_mappings!
        return unless sync_section

        unless sync_section.is_a?(Hash)
          raise Dotsync::ConfigError,
            "Configuration error: [sync] must be a table, not an array. " \
            "Use [[sync.mappings]] for explicit mappings."
        end

        validate_explicit_mappings!
        validate_shorthand_mappings!
      end

      def validate_explicit_mappings!
        return unless sync_section.key?(MAPPINGS_KEY)

        explicit_mappings_raw.each_with_index do |mapping, index|
          unless mapping.is_a?(Hash) && mapping.key?("local") && mapping.key?("remote")
            raise Dotsync::ConfigError,
              "Configuration error in sync.mappings ##{index + 1}: " \
              "Each mapping must have 'local' and 'remote' keys."
          end
        end
      end

      def validate_shorthand_mappings!
        SHORTHANDS.each_key do |shorthand_type|
          next unless sync_section.key?(shorthand_type)

          Array(sync_section[shorthand_type]).each_with_index do |mapping, index|
            unless mapping.is_a?(Hash)
              raise Dotsync::ConfigError,
                "Configuration error in sync.#{shorthand_type} ##{index + 1}: " \
                "Each mapping must be a table."
            end
          end
        end
      end
  end
end
