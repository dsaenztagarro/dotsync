# frozen_string_literal: true

require "toml-rb"

module Dotsync
  class ConfigMerger
    attr_reader :include_path

    def self.resolve(config_hash, config_path)
      new(config_hash, config_path).resolve
    end

    def initialize(config_hash, config_path)
      @config = config_hash
      @config_path = config_path
      @include_path = nil
    end

    def resolve
      return @config unless @config.key?("include")

      validate_include_value!
      @include_path = resolve_include_path
      validate_include_exists!

      base_config = load_base_config
      validate_no_chained_includes!(base_config)

      merged = deep_merge(base_config, overlay)
      merged
    end

    private
      def validate_include_value!
        unless @config["include"].is_a?(String)
          raise ConfigError, "Config Error: 'include' must be a string path, got #{@config["include"].class}"
        end
      end

      def resolve_include_path
        include_value = @config["include"]
        config_dir = File.dirname(@config_path)
        File.expand_path(include_value, config_dir)
      end

      def validate_include_exists!
        unless File.exist?(@include_path)
          raise ConfigError, "Config Error: Included file not found: #{@include_path}"
        end
      end

      def load_base_config
        TomlRB.load_file(@include_path)
      end

      def validate_no_chained_includes!(base_config)
        if base_config.key?("include")
          raise ConfigError, "Config Error: Chained includes are not supported (found 'include' in #{@include_path})"
        end
      end

      def overlay
        @config.reject { |key, _| key == "include" }
      end

      def deep_merge(base, overlay)
        base.merge(overlay) do |_key, base_val, overlay_val|
          if base_val.is_a?(Hash) && overlay_val.is_a?(Hash)
            deep_merge(base_val, overlay_val)
          elsif base_val.is_a?(Array) && overlay_val.is_a?(Array)
            base_val + overlay_val
          else
            overlay_val
          end
        end
      end
  end
end
