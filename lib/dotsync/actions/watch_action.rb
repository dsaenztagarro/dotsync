module Dotsync
  class WatchAction
    extend Forwardable

    def_delegator :@logger, :log

    def initialize(logger: nil, config: nil)
      @logger = logger || Dotsync::Logger.new
      @config = config || Dotsync::WatchActionConfig.new
      setup_trap_signals
      setup_listeners
    rescue Dotsync::ConfigError => e
      log(:error, e.message, icon: :error)
      # binding.irb
      exit
    end

    def run
      log(:info, "Watched paths:", icon: :watch)
      config.watched_paths.each { |path| log(:info, "  #{path}") }

      log(:info, "Output directory:", icon: :output)
      log(:info, "  #{@config.output_directory}")

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
        @listeners = @config.watched_paths.map do |watched_path|
          watched_path = File.expand_path(watched_path)
          base = File.directory?(watched_path) ? watched_path : File.dirname(watched_path)
          pattern = File.directory?(watched_path) ? nil : /^#{Regexp.escape(File.basename(watched_path))}$/

          copy_proc = Proc.new do |modified, added, _removed|
            # log(:info, watched_path, icon: :bell)
            (modified + added).each do |path|
              copy_file(path)
            end
          end

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
        dest_path = File.join(@config.output_dir, relative_path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        FileUtils.cp(path, dest_path)
        log(:event, "Copied file", icon: :copy)
        log(:info, "  #{path} → #{dest_path}")
      end
  end
end
