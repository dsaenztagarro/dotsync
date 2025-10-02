module Dotsync
  class Runner
    def initialize(logger: nil)
      @logger = logger || Dotsync::Logger.new
    end

    # action_name should be a symbol, e.g., :pull, :watch, :sync
    def run(action_name)
      begin
        action_class = Dotsync.const_get("#{camelize(action_name.to_s)}Action")
        config_class = Dotsync.const_get("#{camelize(action_name.to_s)}ActionConfig")

        config = config_class.new(Dotsync.config_path)
        action = action_class.new(config, @logger)
        action.execute
      rescue ConfigError => e
        @logger.error("[#{action_name}] config error: #{e.message}")
      rescue NameError => e
        @logger.error("Unknown action '#{action_name}' (#{e.message})")
      rescue => e
        @logger.error("Error running '#{action_name}': #{e.message}")
        raise
      end
    end

    private

    # Utility to convert 'pull' to 'Pull', 'sync' to 'Sync', etc.
    def camelize(str)
      str.split('_').map(&:capitalize).join
    end
  end
end
