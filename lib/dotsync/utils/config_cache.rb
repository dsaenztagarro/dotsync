# frozen_string_literal: true

require "json"
require "digest"
require_relative "config_merger"

module Dotsync
  class ConfigCache
    include Dotsync::XDGBaseDirectory
    include Dotsync::PathUtils

    def initialize(config_path)
      @config_path = File.expand_path(config_path)
      @cache_dir = File.join(xdg_data_home, "dotsync", "config_cache")

      # Use hash of real path for cache filename to support multiple configs
      cache_key = Digest::SHA256.hexdigest(File.realpath(@config_path))
      @cache_file = File.join(@cache_dir, "#{cache_key}.cache")
      @meta_file = File.join(@cache_dir, "#{cache_key}.meta")
    end

    def load
      # Skip cache if disabled via environment variable
      return resolve_config if ENV["DOTSYNC_NO_CACHE"]

      return parse_and_cache unless valid_cache?

      # Fast path: load from cache
      Marshal.load(File.binread(@cache_file))
    rescue ConfigError
      raise
    rescue StandardError
      # Fallback: reparse if cache corrupted or any error
      parse_and_cache
    end

    private
      def valid_cache?
        return false unless File.exist?(@cache_file)
        return false unless File.exist?(@meta_file)

        meta = JSON.parse(File.read(@meta_file))
        source_stat = File.stat(@config_path)

        # Quick validation checks
        return false if source_stat.mtime.to_f != meta["source_mtime"]
        return false if source_stat.size != meta["source_size"]
        return false if Dotsync::VERSION != meta["dotsync_version"]

        # Age check (invalidate cache older than 7 days for safety)
        cache_age_days = (Time.now.to_f - meta["cached_at"]) / 86400
        return false if cache_age_days > 7

        # Check source file validity if present
        if meta["source_file_path"]
          return false unless File.exist?(meta["source_file_path"])

          source_file_stat = File.stat(meta["source_file_path"])
          return false if source_file_stat.mtime.to_f != meta["source_file_mtime"]
          return false if source_file_stat.size != meta["source_file_size"]
        end

        # Check include file validity if present
        if meta["include_path"]
          return false unless File.exist?(meta["include_path"])

          include_stat = File.stat(meta["include_path"])
          return false if include_stat.mtime.to_f != meta["include_mtime"]
          return false if include_stat.size != meta["include_size"]
        end

        true
      rescue StandardError
        # Any error in validation means invalid cache
        false
      end

      def parse_and_cache
        config = resolve_config

        # Write cache files
        begin
          FileUtils.mkdir_p(@cache_dir)
          File.binwrite(@cache_file, Marshal.dump(config))
          File.write(@meta_file, JSON.generate(build_metadata))
        rescue StandardError
          # If caching fails, still return the parsed config
        end

        config
      end

      def resolve_config
        raw = parse_toml
        if raw.key?("source")
          resolve_source(raw)
        else
          @merger = ConfigMerger.new(raw, @config_path)
          @merger.resolve
        end
      end

      def resolve_source(raw)
        validate_source!(raw)
        @source_path = resolve_source_path(raw["source"])
        validate_source_exists!

        source_raw = parse_toml_file(@source_path)
        validate_no_chained_source!(source_raw)

        @merger = ConfigMerger.new(source_raw, @source_path)
        @merger.resolve
      end

      def validate_source!(raw)
        unless raw["source"].is_a?(String)
          raise ConfigError, "Config Error: 'source' must be a string path, got #{raw["source"].class}"
        end

        if raw.keys.any? { |k| k != "source" }
          raise ConfigError,
            "Config Error: 'source' cannot be combined with other keys. " \
            "The source file should contain the full configuration."
        end
      end

      def resolve_source_path(source_value)
        expanded = expand_env_vars(source_value)
        File.expand_path(expanded)
      end

      def validate_source_exists!
        unless File.exist?(@source_path)
          raise ConfigError, "Config Error: Source file not found: #{@source_path}"
        end
      end

      def validate_no_chained_source!(config)
        if config.key?("source")
          raise ConfigError, "Config Error: Chained sources are not supported (found 'source' in #{@source_path})"
        end
      end

      def parse_toml
        parse_toml_file(@config_path)
      end

      def parse_toml_file(path)
        require "toml-rb"
        TomlRB.load_file(path)
      end

      def build_metadata
        source_stat = File.stat(@config_path)
        meta = {
          source_path: @config_path,
          source_size: source_stat.size,
          source_mtime: source_stat.mtime.to_f,
          cached_at: Time.now.to_f,
          dotsync_version: Dotsync::VERSION
        }

        if @source_path
          source_file_stat = File.stat(@source_path)
          meta[:source_file_path] = @source_path
          meta[:source_file_mtime] = source_file_stat.mtime.to_f
          meta[:source_file_size] = source_file_stat.size
        end

        if @merger&.include_path
          include_stat = File.stat(@merger.include_path)
          meta[:include_path] = @merger.include_path
          meta[:include_mtime] = include_stat.mtime.to_f
          meta[:include_size] = include_stat.size
        end

        meta
      end
  end
end
