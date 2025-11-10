# frozen_string_literal: true

require "net/http"
require "json"
require "time"
require "fileutils"

module Dotsync
  class VersionChecker
    include Dotsync::XDGBaseDirectory

    RUBYGEMS_API_URL = "https://rubygems.org/api/v1/versions/dotsync/latest.json"
    CHECK_INTERVAL = 86400 # 24 hours in seconds
    REQUEST_TIMEOUT = 3 # seconds

    def initialize(current_version, logger: nil)
      @current_version = current_version
      @logger = logger
    end

    # Returns true if we should check for updates (cache expired or doesn't exist)
    def should_check?
      return false if ENV["DOTSYNC_NO_UPDATE_CHECK"]
      return true unless File.exist?(cache_file_path)

      Time.now - last_check_time > CHECK_INTERVAL
    rescue => e
      # If we can't determine, be conservative and don't check
      debug_log("Error checking if should check: #{e.message}")
      false
    end

    # Main method to check for updates and display message if needed
    def check_for_updates
      return unless should_check?

      latest_version = fetch_latest_version
      return unless latest_version

      update_cache

      display_update_message(latest_version) if version_outdated?(@current_version, latest_version)
    rescue => e
      # Silently fail - never break the application
      debug_log("Error checking for updates: #{e.message}")
    end

    private
      def cache_file_path
        @cache_file_path ||= File.join(xdg_cache_home, "dotsync", "last_version_check")
      end

      def last_check_time
        return Time.at(0) unless File.exist?(cache_file_path)

        Time.parse(File.read(cache_file_path).strip)
      rescue => e
        debug_log("Error reading cache time: #{e.message}")
        Time.at(0)
      end

      def update_cache
        FileUtils.mkdir_p(File.dirname(cache_file_path))
        File.write(cache_file_path, Time.now.iso8601)
      rescue => e
        debug_log("Error updating cache: #{e.message}")
      end

      def fetch_latest_version
        uri = URI(RUBYGEMS_API_URL)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: REQUEST_TIMEOUT, read_timeout: REQUEST_TIMEOUT) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request)
        end

        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        data["version"]
      rescue => e
        debug_log("Error fetching latest version: #{e.message}")
        nil
      end

      def version_outdated?(current, latest)
        Gem::Version.new(current) < Gem::Version.new(latest)
      rescue => e
        debug_log("Error comparing versions: #{e.message}")
        false
      end

      def display_update_message(latest_version)
        msg = "\n"
        msg += "\e[38;5;226m" # Yellow color
        msg += "A new version of dotsync is available: #{latest_version} "
        msg += "(current: #{@current_version})\n"
        msg += "Run 'gem update dotsync' to upgrade"
        msg += "\e[0m\n" # Reset color

        $stderr.puts msg
      end

      def debug_log(message)
        return unless ENV["DEBUG"]

        if @logger
          @logger.log("Debug: #{message}")
        else
          $stderr.puts "Debug: #{message}"
        end
      end
  end
end
