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

    private

      def show_options(options)
        info("Options:", icon: :options)
        logger.log("  Apply: #{options[:apply] ? "TRUE" : "FALSE"}")
      end
  end
end
