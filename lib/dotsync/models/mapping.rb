# frozen_string_literal: true

module Dotsync
  class Mapping
    include Dotsync::PathUtils

    attr_reader :original_src, :original_dest, :original_ignores, :original_only

    def initialize(attributes)
      @original_src = attributes["src"]
      @original_dest = attributes["dest"]
      @original_ignores = Array(attributes["ignore"])
      @original_only = Array(attributes["only"])
      @force = attributes["force"] || false

      @sanitized_src, @sanitized_dest, @sanitized_ignore, @sanitized_only = process_paths(
        @original_src,
        @original_dest,
        @original_ignores,
        @original_only
      )
    end

    def src
      @sanitized_src
    end

    def dest
      @sanitized_dest
    end

    def ignores
      @sanitized_ignore
    end

    def inclusions
      @sanitized_only
    end

    def force?
      @force
    end

    def directories?
      File.directory?(src) && File.directory?(dest)
    end

    def files?
      files_present? || file_present_in_src_only?
    end

    def files_present?
      File.file?(src) && File.file?(dest)
    end

    def file_present_in_src_only?
      File.file?(src) && !File.exist?(dest) && File.directory?(File.dirname(dest))
    end

    def valid?
      directories? || files? || file_present_in_src_only?
    end

    def file_changed?
      files_present? && (File.size(src) != File.size(dest))
    end

    def backup_possible?
      valid? && File.exist?(dest)
    end

    def backup_basename
      return unless valid?
      return File.dirname(dest) unless File.exist?(dest)
      File.basename(dest)
    end

    def icons
      msg = []
      msg << Icons.invalid unless valid?
      msg << Icons.only if only?
      msg << Icons.ignore if ignores?
      msg << Icons.force if force?
      msg.join(" ")
    end

    def to_s
      msg = "#{decorated_src} → #{decorated_dest}"
      msg += " #{icons}" if icons != ""
      msg
    end

    def decorated_src
      colorize_env_vars(original_src)
    end

    def decorated_dest
      colorize_env_vars(original_dest)
    end

    def apply_to(path)
      relative_path = if Pathname.new(path).absolute?
        path.delete_prefix(File.join(src, "/"))
      else
        path
      end

      Dotsync::Mapping.new(
        "src" => File.join(@original_src, relative_path),
        "dest" => File.join(@original_dest, relative_path),
        "force" => @force,
        "only" => @only,
        "ignore" => @original_ignores
      )
    end

    private
      def ignores?
        @original_ignores.any?
      end

      def only?
        @original_only.any?
      end

      def process_paths(raw_src, raw_dest, raw_ignores, raw_only)
        sanitized_src = sanitize_path(raw_src)
        sanitized_dest = sanitize_path(raw_dest)
        sanitized_ignore = raw_ignores.flat_map do |path|
          [File.join(sanitized_src, path), File.join(sanitized_dest, path)]
        end
        sanitized_only = raw_only.map do |path|
          File.join(sanitized_src, path)
        end
        [sanitized_src, sanitized_dest, sanitized_ignore, sanitized_only]
      end
  end
end
