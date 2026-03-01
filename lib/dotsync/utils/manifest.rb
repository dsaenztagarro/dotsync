# frozen_string_literal: true

require "json"

module Dotsync
  class Manifest
    MANIFESTS_DIR = "dotsync/manifests"

    # @param dest_dir [String] the mapping's destination directory (absolute)
    # @param key [String] manifest filename key (e.g., "xdg_bin")
    # @param xdg_data_home [String] base path for manifest storage
    def initialize(dest_dir:, key:, xdg_data_home:)
      @dest_dir = dest_dir
      @key = key
      @manifest_path = File.join(xdg_data_home, MANIFESTS_DIR, "#{key}.json")
    end

    # Returns array of relative file paths from stored manifest
    # @return [Array<String>]
    def read
      return [] unless File.exist?(@manifest_path)

      data = JSON.parse(File.read(@manifest_path))
      Array(data["files"])
    rescue JSON::ParserError
      []
    end

    # Writes current file list to manifest
    # @param files [Array<String>] relative file paths
    def write(files)
      FileUtils.mkdir_p(File.dirname(@manifest_path))
      File.write(@manifest_path, JSON.pretty_generate({ "files" => files.sort }))
    end

    # Returns orphan absolute paths: files in old manifest but not in current_files
    # @param current_files [Array<String>] relative file paths currently synced
    # @return [Array<String>] absolute paths ready for deletion
    def orphans(current_files)
      previous = read
      orphaned = previous - current_files
      orphaned.map { |file| File.join(@dest_dir, file) }
    end
  end
end
