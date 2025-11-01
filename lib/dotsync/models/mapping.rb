# frozen_string_literal: true

module Dotsync
  class Mapping
    include Dotsync::PathUtils

    attr_reader :original_src, :original_dest, :original_ignores

    def initialize(attributes)
      @original_src = attributes["src"]
      @original_dest = attributes["dest"]
      @original_ignores = Array(attributes["ignore"])
      @force = attributes["force"] || false

      @sanitized_src, @sanitized_dest, @sanitized_ignore = process_paths(
        @original_src,
        @original_dest,
        @original_ignores
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

    def force?
      @force
    end

    def directories?
      File.directory?(src) && File.directory?(dest)
    end

    def files?
      return true if File.file?(src) && File.file?(dest)
      File.file?(src) && !File.exist?(dest) && File.directory?(File.dirname(dest))
    end

    def valid?
      directories? || files?
    end

    def backup_possible?
      valid? && File.exist?(dest)
    end

    def backup_basename
      return unless valid?
      return File.dirname(dest) unless File.exist?(dest)
      File.basename(dest)
    end

    def to_s
      colorized_src = colorize_env_vars(original_src)
      colorized_dest = colorize_env_vars(original_dest)
      msg = ["#{colorized_src} → #{colorized_dest}"]
      msg << Icons.force if force?
      msg << Icons.ignore if ignores?
      msg << Icons.invalid unless valid?
      msg.join(" ")
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
        "ignore" => @original_ignores
      )
    end

    private
      def ignores?
        @original_ignores.any?
      end

      def process_paths(src, dest, ignores)
        sanitized_src = sanitize_path(src)
        sanitized_dest = sanitize_path(dest)
        sanitized_ignore = ignores.flat_map do |path|
          [File.join(sanitized_src, path), File.join(sanitized_dest, path)]
        end
        [sanitized_src, sanitized_dest, sanitized_ignore]
      end
  end
end
