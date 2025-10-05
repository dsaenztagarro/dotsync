module Dotsync
  class WatchAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :watched_paths

    def initialize(config, logger)
      super
      setup_listeners
    end

    def execute
      info("Watched paths:", icon: :watch)
      watched_paths.each { |path| info("  #{path}") }
      info("Destination:", icon: :dest)
      info("  #{dest}")
      info("")

      @listeners.each(&:start)

      logger.action("Listening for changes...", icon: :listen)
      info("Press Ctrl+C to exit.")
      sleep
    end

    private

      def setup_listeners
        @listeners = watched_paths.map do |watched_path|
          watched_path = File.expand_path(watched_path)
          # Determine the base directory to watch. If it's a directory, use it directly.
          # Otherwise, use its parent directory.
          base = File.directory?(watched_path) ? watched_path : File.dirname(watched_path)

          # If the watched path is a file, create a pattern to match its name.
          # Otherwise, set the pattern to nil.
          pattern = File.directory?(watched_path) ? nil : /^#{Regexp.escape(File.basename(watched_path))}$/

          # Define a procedure to handle file changes (modified or added files)
          copy_proc = Proc.new do |modified, added, _removed|
            # For each modified or added file, copy it to the destination
            (modified | added).each do |path|
              copy_file(path)
            end
          end

          # Create a listener. If a pattern is defined, watch only files matching the pattern. Otherwise, watch all changes in the base directory.
          if pattern
            Listen.to(base, only: pattern, &copy_proc)
          else
            Listen.to(base, &copy_proc)
          end
        end
      end

      def copy_file(path)
        sanitized_src = sanitize_path(src)
        sanitized_path = sanitize_path(path)
        relative_path = sanitized_path.delete_prefix(sanitized_src)
        dest_path = File.join(dest, relative_path)
        sanitized_dest = sanitize_path(dest_path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        FileUtils.cp(path, sanitized_dest)
        info("Copied file", icon: :copy)
        info("  ~/#{relative_path} → #{sanitized_dest}")
      end
  end
end
