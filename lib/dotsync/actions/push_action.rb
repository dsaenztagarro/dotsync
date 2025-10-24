module Dotsync
  class PushAction < BaseAction
    def_delegator :@config, :mappings

    def execute
      show_config
      push_dotfiles
    end

    private

    def show_config
      info("Mappings:", icon: :config)
      mappings.each { |mapping| info("  #{mapping}") }
    end

    def push_dotfiles
      mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end
      action("Dotfiles pushed", icon: :copy)
    end

    def icon_delete
      Dotsync::Logger::ICONS[:delete]
    end
  end
end
