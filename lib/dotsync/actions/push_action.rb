# frozen_string_literal: true

module Dotsync
  class PushAction < BaseAction
    include MappingsTransfer

    def execute(options = {})
      show_options(options)
      show_env_vars
      show_mappings_legend
      show_mappings
      show_differences
      return unless options[:apply]

      transfer_mappings
      action("Mappings pushed", icon: :done)
    end
  end
end
