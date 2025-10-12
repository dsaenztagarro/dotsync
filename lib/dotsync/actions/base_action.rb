module Dotsync
  class BaseAction
    include Dotsync::PathUtils

    extend Forwardable # def_delegator

    attr_reader :logger
    def_delegator :logger, :info
    def_delegator :logger, :action

    def initialize(config, logger)
      @log_queue = Queue.new
      @config = config
      @logger = logger
      setup_logger_thread
      setup_trap_signals
    end

    def execute
      raise NotImplementedError
    end

    private

      def setup_trap_signals
        Signal.trap("INT") do
          @log_queue << { type: :info, message: "Shutting down gracefully...", icon: :bell }
          exit
        end
      end

      def setup_logger_thread
        return if ENV['TEST_ENV'] == 'true'

        Thread.new do
          loop do
            log_entry = @log_queue.pop
            @logger.info(log_entry[:message], icon: log_entry[:icon])
          end
        end
      end
  end
end
