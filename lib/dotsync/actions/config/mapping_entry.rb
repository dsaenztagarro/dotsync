module Dotsync
  class MappingEntry
    include Dotsync::PathUtils

    attr_reader :original_src, :original_dest, :original_ignores

    def initialize(hash)
      @original_src = hash["src"]
      @original_dest = hash["dest"]
      @original_ignores = Array(hash["ignore"])
      @force = hash["force"] || false

      @sanitized_src = sanitize_path(@original_src)
      @sanitized_dest = sanitize_path(@original_dest)
      @sanitized_ignore = @original_ignores.map { |path| File.join(@sanitized_src, path) }
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

    def valid?
      File.exist?(@sanitized_src) && File.exist?(File.dirname(@sanitized_dest))
    end

    def to_s
      msg = ["#{original_src} → #{original_dest}"]
      msg << Icons::FORCE if force?
      msg << Icons::IGNORE if ignores?
      msg << Icons::INVALID unless valid?
      msg.join(" ")
    end

    def applied_to(path)
      relative_path = if Pathname.new(path).absolute?
        path.delete_prefix(File.join(src, "/"))
      else
        path
      end

      Dotsync::MappingEntry.new(
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
  end
end

