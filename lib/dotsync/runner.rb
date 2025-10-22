module Dotsync
  class Runner
    def initialize(logger: nil)
      @logger = logger || Dotsync::Logger.new
    end

    # action_name should be a symbol, e.g., :pull, :watch, :sync
    def run(action_name)
      case action_name
      when :setup
        setup_config
      else
        begin
          action_class = Dotsync.const_get("#{camelize(action_name.to_s)}Action")
          config_class = Dotsync.const_get("#{camelize(action_name.to_s)}ActionConfig")

          config = config_class.new(Dotsync.config_path)
          action = action_class.new(config, @logger)
          action.execute
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
        end
      end
    end

    private

    def setup_config
      require 'toml-rb'
      require 'fileutils'

      config_path = File.expand_path(Dotsync.config_path)
      FileUtils.mkdir_p(File.dirname(config_path))

      example_mappings = {
        "pull" => {
          "mappings" => [
            { "src" => "$DOTFILES_DIR/config/", "dest" => "$XDG_CONFIG_HOME", "force" => false },
            { "src" => "$DOTFILES_DIR/home/.zshenv", "dest" => "$HOME" }
          ],
        },
        "push" => {
          "mappings" => [
            { "src" => "$HOME/.zshenv", "dest" => "$DOTFILES_DIR/home/.zshenv" },
            { "src" => "$XDG_CONFIG_HOME/alacritty", "dest" => "$DOTFILES_DIR/config/alacritty" }
          ]
        },
        "watch" => {
          "mappings" => [
            { "src" => "$HOME/.zshenv", "dest" => "$DOTFILES_DIR/home/.zshenv" },
            { "src" => "$XDG_CONFIG_HOME/alacritty", "dest" => "$DOTFILES_DIR/config/alacritty" }
          ]
        }
      }

      File.write(config_path, TomlRB.dump(example_mappings))
      @logger.info("Configuration file created at #{config_path}")
    end

    # Utility to convert 'pull' to 'Pull', 'sync' to 'Sync', etc.
    def camelize(str)
      str.split('_').map(&:capitalize).join
    end
  end
end
