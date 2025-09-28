module Dotsync
  class Watch
    include Configurable
    extend Forwardable

    def_delegator :@logger, :log

    def initialize(logger = Dotsync::Logger.new)
      @logger = logger
      load_config
      setup_listeners
    end

    def load_config
      unless File.exist?(CONFIG_PATH)
        abort("Config file not found at #{CONFIG_FILE}")
      end

      watch_config = CONFIG['watch']

      unless watch_config
        abort("No [watch] section found in #{CONFIG_FILE}")
      end

      @output_dir = File.expand_path(watch_config['output_dir'])
      @watch_paths = watch_config['paths'].map { |path| File.expand_path(path) }

      log(:info, "Watching paths:", icon: :watch)
      @watch_paths.each { |path| log(:info, "  #{path}") }
      log(:info, "Output directory:", icon: :output)
      log(:info, "  #{@output_dir}")
    end

    def setup_listeners
      @listeners = @watch_paths.map do |watch_path|
        base = File.directory?(watch_path) ? watch_path : File.dirname(watch_path)
        pattern = File.directory?(watch_path) ? nil : /^#{Regexp.escape(File.basename(watch_path))}$/

        copy_proc = Proc.new do |modified, added, _removed|
          # log(:info, watch_path, icon: :bell)
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

    def start
      Signal.trap("INT") do
        puts "\nShutting down..."
        exit
      end

      @listeners.each(&:start)
      log(:info, "Listening for changes. Press Ctrl+C to exit.")
      sleep
    end

    private

    def copy_file(path)
      home = Dir.home
      home_with_slash = home.end_with?("/") ? home : "#{home}/"
      relative_path = path.delete_prefix(home_with_slash)
      dest_path = File.join(@output_dir, relative_path)
      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(path, dest_path)
      log(:event, "Copied file", icon: :copy)
      log(:info, "  #{path} → #{dest_path}")
    end
  end
end

