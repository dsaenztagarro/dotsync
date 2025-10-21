module Dotsync
  class MappingEntry
    include Dotsync::PathUtils

    attr_reader :original_src, :original_dest, :original_ignore

    def initialize(hash)
      @original_src = hash["src"]
      @original_dest = hash["dest"]
      @original_ignore = Array(hash["ignore"])
      @force = hash["force"] || false

      @sanitized_src = sanitize_path(File.expand_path(@original_src))
      @sanitized_dest = sanitize_path(File.expand_path(@original_dest))
      @sanitized_ignore = @original_ignore.map { |path| sanitize_path(File.expand_path(path, @sanitized_src)) }
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
      File.exist?(@sanitized_src) && File.exist?(@sanitized_dest)
    end
  end
end

