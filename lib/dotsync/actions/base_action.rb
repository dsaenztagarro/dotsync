# frozen_string_literal: true

module Dotsync
  class BaseAction
    include Dotsync::PathUtils

    extend Forwardable # def_delegator

    attr_reader :logger
    def_delegator :logger, :info
    def_delegator :logger, :action

    def initialize(config, logger)
      @config = config
      @logger = logger
    end

    def execute
      raise NotImplementedError
    end
  end
end
