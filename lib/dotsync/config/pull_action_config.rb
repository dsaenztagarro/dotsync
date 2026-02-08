# frozen_string_literal: true

module Dotsync
  class PullActionConfig < BaseConfig
    include XDGBaseDirectory
    include SyncMappings

    def mappings
      section_mappings + sync_mappings_for_pull
    end

    def backups_root
      File.join(xdg_data_home, "dotsync", "backups")
    end

    private
      SECTION_NAME = "pull"

      def section_name
        SECTION_NAME
      end

      def section_mappings
        return [] unless section && section["mappings"]
        Array(section["mappings"]).map do |mapping|
          attrs = mapping.dup
          if attrs.key?("hooks") && attrs["hooks"].is_a?(Hash)
            resolved = Array(attrs["hooks"]["post_pull"])
            attrs["hooks"] = resolved.any? ? resolved : nil
            attrs.delete("hooks") unless attrs["hooks"]
          end
          Dotsync::Mapping.new(attrs)
        end
      end

      def validate!
        validate_pull_or_sync_present!
        validate_pull_mappings!
        validate_sync_mappings!
      end

      def validate_pull_or_sync_present!
        has_pull = @config.key?(section_name) && section["mappings"]&.any?

        unless has_pull || has_sync_mappings?
          raise_error "No [#{section_name}] mappings or [sync] mappings found in config file"
        end
      end

      def validate_pull_mappings!
        return unless section && section["mappings"]

        Array(section["mappings"]).each_with_index do |mapping, index|
          unless mapping.is_a?(Hash) && mapping.key?("src") && mapping.key?("dest")
            raise "Configuration error in pull mapping ##{index + 1}: Each mapping must have 'src' and 'dest' keys."
          end

          if mapping.is_a?(Hash) && mapping.key?("hooks") && mapping["hooks"].is_a?(Hash)
            invalid_keys = mapping["hooks"].keys - ["post_pull"]
            if invalid_keys.any?
              raise Dotsync::ConfigError,
                "Configuration error in pull mapping ##{index + 1}: " \
                "Only 'post_pull' hooks are allowed in [pull] mappings. " \
                "Invalid key(s): #{invalid_keys.join(", ")}"
            end
          end
        end
      end
  end
end
