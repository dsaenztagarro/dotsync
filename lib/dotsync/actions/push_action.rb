# frozen_string_literal: true

module Dotsync
  class PushAction < BaseAction
    include MappingsTransfer

    def execute(options = {})
      show_options(options)
      show_env_vars
      show_mappings
      show_changes
      return unless options[:apply]

      transfer_mappings
      action("Dotfiles pushed", icon: :copy)
    end
  end
end
