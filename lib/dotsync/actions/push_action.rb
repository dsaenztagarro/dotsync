module Dotsync
  class PushAction < BaseAction
    def_delegator :@config, :mappings

    def execute
      show_config
      push_dotfiles
    end

    private

    def show_config
      info("Mappings:", icon: :source_dest)
      mappings.each do |mapping|
        force_icon = mapping.force? ? " #{icon_delete}" : ""
        info("  src: #{mapping.original_src} -> dest: #{mapping.original_dest}#{force_icon}", icon: :copy)
        info("    ignores: #{mapping.original_ignores.join(', ')}", icon: :exclude) if mapping.ignores.any?
      end
    end

    def push_dotfiles
      mappings.each { |mapping| Dotsync::FileTransfer.new(mapping).transfer }
      action("Dotfiles pushed", icon: :copy)
    end

    def icon_delete
      Dotsync::Logger::ICONS[:delete]
    end
  end
end
