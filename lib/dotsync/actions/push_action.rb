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
        info("Source: #{mapping[:src]} -> Destination: #{mapping[:dest]}", icon: :copy)
        info("Remove destination: #{mapping[:force]}", icon: :delete)
        info("Exclude paths: #{mapping[:exclude_paths].join(', ')}", icon: :exclude) if mapping[:exclude_paths]&.any?
        info("")
      end
    end

    def push_dotfiles
      mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end

      action("Dotfiles pushed", icon: :copy)
    end
  end
end
