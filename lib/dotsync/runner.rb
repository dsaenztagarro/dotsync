# frozen_string_literal: true

module Dotsync
  class Runner
    def initialize(logger: nil, config_path: nil)
      @logger = logger || Dotsync::Logger.new
      @config_path = config_path
    end

    # action_name should be a symbol, e.g., :pull, :watch, :sync
    def run(action_name, options = {})
      case action_name
      when :setup
        setup_config
      else
        begin
          action_class = Dotsync.const_get("#{camelize(action_name.to_s)}Action")
          config_class = Dotsync.const_get("#{camelize(action_name.to_s)}ActionConfig")

          config = config_class.new(Dotsync.config_path)
          Dotsync::Icons.load_custom_icons(config.to_h)
          Dotsync::Colors.load_custom_colors(config.to_h)

          action = action_class.new(config, @logger)

          action.execute(options)
        rescue ConfigError => e
          @logger.error("[#{action_name}] config error:")
          @logger.info(e.message)
        rescue NameError => e
          @logger.error("Unknown action '#{action_name}':")
          @logger.info(e.message)
        rescue => e
          @logger.error("Error running '#{action_name}':")
          @logger.info(e.message)
          raise
        ensure
          check_for_updates
        end
      end
    end

    private
      def setup_config
        require "toml-rb"
        require "fileutils"

        config_path = File.expand_path(@config_path || Dotsync.config_path)
        FileUtils.mkdir_p(File.dirname(config_path))

        example_mappings = {
          "icons" => {
            "options" => "⚙️",
            "config" => "📄",
            "force" => "🔥",
            "ignore" => "🚫",
            "invalid" => "❌"
          },
          "pull" => {
            "mappings" => [
              { "src" => "$XDG_CONFIG_HOME_MIRROR", "dest" => "$XDG_CONFIG_HOME" },
              { "src" => "$HOME_MIRROR/.zshenv", "dest" => "$HOME" }
            ],
          },
          "push" => {
            "mappings" => [
              { "src" => "$HOME/.zshenv", "dest" => "$DOTFILES_DIR/home/.zshenv" },
              { "src" => "$XDG_CONFIG_HOME/alacritty", "dest" => "$XDG_CONFIG_HOME_MIRROR/alacritty" }
            ]
          },
          "watch" => {
            "mappings" => [
              { "src" => "$HOME/.zshenv", "dest" => "$HOME_MIRROR/.zshenv" },
              { "src" => "$XDG_CONFIG_HOME/alacritty", "dest" => "$DOTFILES_DIR/config/alacritty" }
            ]
          }
        }

        File.write(config_path, TomlRB.dump(example_mappings))
        @logger.info("Configuration file created at #{config_path}")
      end

      # Check for available updates
      def check_for_updates
        return if ENV["DOTSYNC_NO_UPDATE_CHECK"]

        checker = Dotsync::VersionChecker.new(Dotsync::VERSION, logger: @logger)
        checker.check_for_updates if checker.should_check?
      rescue => e
        # Silently fail - never break the tool
        @logger.log("Debug: Version check failed - #{e.message}") if ENV["DEBUG"]
      end

      # Utility to convert 'pull' to 'Pull', 'sync' to 'Sync', etc.
      def camelize(str)
        str.split("_").map(&:capitalize).join
      end
  end
end
