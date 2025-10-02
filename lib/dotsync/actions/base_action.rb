module Dotsync
  class BaseAction
    extend Forwardable # def_delegator

    def_delegator :@logger, :log

    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    def execute
      raise NotImplementedError
    end
  end
end
