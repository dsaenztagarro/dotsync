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
        info("Source: #{mapping.original_src} -> Destination: #{mapping.original_dest}", icon: :copy)
        info("Remove destination: #{mapping.force?}", icon: :delete)
        info("Exclude paths: #{mapping.ignores.join(', ')}", icon: :exclude) if mapping.ignores.any?
        info("")
      end
    end

    def push_dotfiles
      mappings.each { |mapping| Dotsync::FileTransfer.new(mapping).transfer }
      action("Dotfiles pushed", icon: :copy)
    end
  end
end
