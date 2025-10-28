# frozen_string_literal: true

module Dotsync
  class PushAction < BaseAction
    include MappingsTransfer

    def execute
      show_config
      show_changes
      push_dotfiles
    end

    private
      def show_config
        show_mappings
      end

      def push_dotfiles
        transfer_mappings

        action("Dotfiles pushed", icon: :copy)
      end
  end
end
