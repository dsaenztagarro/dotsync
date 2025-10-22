module Dotsync
  class WatchAction < BaseAction
    def_delegator :@config, :mappings

    def initialize(config, logger)
      super
      setup_listeners
      setup_logger_thread
      setup_signal_trap
    end

    def execute
      show_config

      @listeners.each(&:start)

      logger.action("Listening for changes...", icon: :listen)
      info("Press Ctrl+C to exit.")
      sleep
    end

    private

      def show_config
        info("Mappings:", icon: :watch)
        mappings.each do |mapping|
          info("  #{mapping}", icon: :copy)
          info("    Excludes: #{mapping.ignores.join(', ')}", icon: :exclude) if mapping.ignores.any?
        end
      end

      def setup_listeners
        @listeners = mappings.map do |mapping|
          src = mapping.src

          # Determine the base directory to watch. If it's a directory, use it directly.
          # Otherwise, use its parent directory.
          base = File.directory?(src) ? src : File.dirname(src)

          options = {}
          # If the watched path is a file, create a pattern to match its name.
          options[:pattern] = /^#{Regexp.escape(File.basename(src))}$/ unless File.directory?(src)
          options[:ignore] = Regexp.union(mapping.ignores) if mapping.ignores.any?

          Listen.to(base, options) do |modified, added, removed|
            handle_file_changes(mapping, modified, added, removed)
          end
        end
      end

      def handle_file_changes(mapping, modified, added, removed)
        (modified + added).each do |path|
          new_mapping = mapping.applied_to(path)
          logger.info("Copied file: #{new_mapping.original_src}", icon: :copy)
          Dotsync::FileTransfer.new(new_mapping).transfer
        end
        removed.each do |path|
          logger.info("File removed: #{path}", icon: :delete)
        end
      end

      def setup_signal_trap
        listeners = @listeners.dup
        Signal.trap("INT") do
          # Using a new thread to handle the signal trap context,
          # as Signal.trap runs in a more restrictive environment
          Thread.new do
            logger.action("Shutting down listeners...", icon: :bell)
            listeners.each(&:stop)
            exit
          end
        end
      end
  end
end
