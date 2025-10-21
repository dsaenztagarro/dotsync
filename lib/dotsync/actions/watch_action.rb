module Dotsync
  class WatchAction < BaseAction
    def_delegator :@config, :mappings

    def initialize(config, logger)
      super
      setup_listeners
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
          force_icon = mapping.force? ? " #{icon_delete}" : ""
          info("  src: #{mapping.original_src} -> dest: #{mapping.original_dest}#{force_icon}", icon: :copy)
          info("    ignores: #{mapping.ignores.join(', ')}", icon: :exclude) if mapping.ignores.any?
        end
      end

      def setup_listeners
        @listeners = mappings.map do |mapping|
          src = mapping.src

          # Determine the base directory to watch. If it's a directory, use it directly.
          # Otherwise, use its parent directory.
          base = File.directory?(src) ? src : File.dirname(src)

          # If the watched path is a file, create a pattern to match its name.
          # Otherwise, set the pattern to nil.
          pattern = File.directory?(src) ? nil : /^#{Regexp.escape(File.basename(src))}$/

          # Define a procedure to handle file changes (modified or added files)
          copy_proc = Proc.new do |modified, added, _removed|
            # For each modified or added file, copy it to the destination
            (modified | added).each do |path|
              copy_file(path, mapping)
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

      def copy_file(path, mapping)
        mapping = mapping.applied_to(path)
        Dotsync::FileTransfer.new(mapping).transfer if mapping
        info("Copied file", icon: :copy)
        info("  #{mapping.original_src} → #{mapping.original_dest}")
      end
  end
end
