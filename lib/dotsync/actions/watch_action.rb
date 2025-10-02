module Dotsync
  class WatchAction < BaseAction
    def_delegator :@config, :watched_paths
    def_delegator :@config, :output_directory, :output_dir

    def initialize(config, logger)
      super
      setup_trap_signals
      setup_listeners
    end

    def execute
      log(:info, "Watched paths:", icon: :watch)
      watched_paths.each { |path| log(:info, "  #{path}") }

      log(:info, "Output directory:", icon: :output)
      log(:info, "  #{output_dir}")

      @listeners.each(&:start)

      log(:info, "Listening for changes. Press Ctrl+C to exit.")

      sleep
    end

    private

      attr_reader :config

      def setup_trap_signals
        Signal.trap("INT") do
          puts "\nShutting down..."
          exit
        end
      end

      def setup_listeners
        # Iterate over each path in the watched paths
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
        home = Dir.home
        home_with_slash = home.end_with?("/") ? home : "#{home}/"
        relative_path = path.delete_prefix(home_with_slash)
        dest_path = File.join(output_dir, relative_path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        FileUtils.cp(path, dest_path)
        log(:event, "Copied file", icon: :copy)
        log(:info, "  ~/#{relative_path} → #{dest_path}")
      end
  end
end
