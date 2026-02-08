# frozen_string_literal: true

module Dotsync
  class PushActionConfig < BaseConfig
    include SyncMappings

    def mappings
      section_mappings + sync_mappings_for_push
    end

    private
      SECTION_NAME = "push"

      def section_name
        SECTION_NAME
      end

      def section_mappings
        return [] unless section && section["mappings"]
        Array(section["mappings"]).map do |mapping|
          attrs = mapping.dup
          if attrs.key?("hooks") && attrs["hooks"].is_a?(Hash)
            resolved = Array(attrs["hooks"]["post_push"])
            attrs["hooks"] = resolved.any? ? resolved : nil
            attrs.delete("hooks") unless attrs["hooks"]
          end
          Dotsync::Mapping.new(attrs)
        end
      end

      def validate!
        validate_push_or_sync_present!
        validate_push_mappings!
        validate_sync_mappings!
      end

      def validate_push_or_sync_present!
        has_push = @config.key?(section_name) && section["mappings"]&.any?

        unless has_push || has_sync_mappings?
          raise_error "No [#{section_name}] mappings or [sync] mappings found in config file"
        end
      end

      def validate_push_mappings!
        return unless section && section["mappings"]

        Array(section["mappings"]).each_with_index do |mapping, index|
          unless mapping.is_a?(Hash) && mapping.key?("src") && mapping.key?("dest")
            raise "Configuration error in push mapping ##{index + 1}: Each mapping must have 'src' and 'dest' keys."
          end

          if mapping.is_a?(Hash) && mapping.key?("hooks") && mapping["hooks"].is_a?(Hash)
            invalid_keys = mapping["hooks"].keys - ["post_push"]
            if invalid_keys.any?
              raise Dotsync::ConfigError,
                "Configuration error in push mapping ##{index + 1}: " \
                "Only 'post_push' hooks are allowed in [push] mappings. " \
                "Invalid key(s): #{invalid_keys.join(", ")}"
            end
          end
        end
      end
  end
end
