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
      ignore_icon = @original_ignores.empty? ? "" : "  #{Dotsync::Logger::ICONS[:ignore]}"
      force_icon = force? ? " #{ICON_FORCE}" : ""
      ignore_icon = ignores? ? " #{ICON_IGNORE}" : ""
      "#{original_src} → #{original_dest}#{force_icon}#{ignore_icon}"
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

    ICON_FORCE = Dotsync::Logger::ICONS[:clean]
    ICON_IGNORE = Dotsync::Logger::ICONS[:skip]

    def ignores?
      @original_ignores.any?
    end
  end
end

