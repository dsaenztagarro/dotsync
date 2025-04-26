module Dotsync
  class Watch
    include Configurable

    def_delegator :@logger, :log

    def initialize(logger = Dotsync::Logger.new)
      @logger = logger
      load_config
      setup_listeners
    end

    def load_config
      unless File.exist?(CONFIG_FILE)
        abort("Config file not found at #{CONFIG_FILE}")
      end

      config = TOML.load_file(CONFIG_FILE)
      watch_config = config['watch']

      unless watch_config
        abort("No [watch] section found in #{CONFIG_FILE}")
      end

      @output_dir = File.expand_path(watch_config['output_dir'])
      @watch_paths = watch_config['paths'].map { |path| File.expand_path(path) }

      log_info(" Watching paths:")
      @watch_paths.each { |path| log_info("  #{path}") }
      log_info(" Output directory: #{@output_dir}")
    end

    def setup_listeners
      @listeners = @watch_paths.map do |watch_path|
        base = File.directory?(watch_path) ? watch_path : File.dirname(watch_path)
        pattern = File.directory?(watch_path) ? nil : /^#{Regexp.escape(File.basename(watch_path))}$/

        copy_proc = Proc.new do |modified, added, _removed|
          log_info(" #{watch_path}")
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
      @listeners.each(&:start)
      log_info("Listening for changes. Press Ctrl+C to exit.")
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
      log_info(" Copied #{path} → #{dest_path}")
    end
  end
end

