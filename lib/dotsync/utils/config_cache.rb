# frozen_string_literal: true

require "json"
require "digest"

module Dotsync
  class ConfigCache
    include Dotsync::XDGBaseDirectory

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
      return parse_toml if ENV["DOTSYNC_NO_CACHE"]

      return parse_and_cache unless valid_cache?

      # Fast path: load from cache
      Marshal.load(File.binread(@cache_file))
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

        true
      rescue StandardError
        # Any error in validation means invalid cache
        false
      end

      def parse_and_cache
        config = parse_toml

        # Write cache files
        FileUtils.mkdir_p(@cache_dir)
        File.binwrite(@cache_file, Marshal.dump(config))
        File.write(@meta_file, JSON.generate(build_metadata))

        config
      rescue StandardError
        # If caching fails, still return the parsed config
        config
      end

      def parse_toml
        require "toml-rb"
        TomlRB.load_file(@config_path)
      end

      def build_metadata
        source_stat = File.stat(@config_path)
        {
          source_path: @config_path,
          source_size: source_stat.size,
          source_mtime: source_stat.mtime.to_f,
          cached_at: Time.now.to_f,
          dotsync_version: Dotsync::VERSION
        }
      end
  end
end
