# frozen_string_literal: true

require "open3"
require "shellwords"

module Dotsync
  class HookRunner
    include Dotsync::PathUtils

    def initialize(mapping:, changed_files:, logger:)
      @mapping = mapping
      @changed_files = changed_files
      @logger = logger
    end

    def execute
      @mapping.hooks.map do |command|
        expanded = expand_template(command)
        run_command(expanded)
      end
    end

    def preview
      @mapping.hooks.map { |command| expand_template(command) }
    end

    private
      def expand_template(command)
        files_str = @changed_files.map { |f| Shellwords.escape(sanitize_path(f)) }.join(" ")

        command
          .gsub("{files}", files_str)
          .gsub("{src}", @mapping.src)
          .gsub("{dest}", @mapping.dest)
      end

      def run_command(command)
        stdout, stderr, status = Open3.capture3(command)

        if status.success?
          @logger.info("Hook succeeded: #{command}", icon: :hook)
        else
          @logger.error("Hook failed: #{command}")
          @logger.error("  #{stderr.strip}") unless stderr.strip.empty?
        end

        { command: command, stdout: stdout, stderr: stderr, success: status.success? }
      end
  end
end
