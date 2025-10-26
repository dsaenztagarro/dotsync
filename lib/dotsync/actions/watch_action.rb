module Dotsync
  class WatchAction < BaseAction
    def_delegator :@config, :mappings

    def initialize(config, logger)
      super
      setup_listeners
      # setup_logger_thread
      setup_signal_trap
    end

    def execute
      show_config

      @listeners.each(&:start)

      logger.action("Listening for changes...")
      logger.action("Press Ctrl+C to exit.")
      sleep
    end

    private

      def show_config
        logger.info("Mappings:", icon: :config)
        mappings.each { |mapping| logger.log("  #{mapping}") }
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
          logger.info("Copied file: #{new_mapping}", icon: :copy)
          Dotsync::FileTransfer.new(new_mapping).transfer
        end
        removed.each do |path|
          logger.info("File removed: #{path}", icon: :delete, bold: false)
        end
      end

      def setup_signal_trap
        Signal.trap("INT") do
          # Using a new thread to handle the signal trap context,
          # as Signal.trap runs in a more restrictive environment
          Thread.new do
            logger.action("Shutting down listeners...")
            @listeners.each(&:stop)
            exit
          end
        end
      end
  end
end
