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

      mappings.each do |mapping|
        info("  #{mapping}")
      end
    end

    def push_dotfiles
      valid_mappings, invalid_mappings = mappings.partition(&:valid?)

      valid_mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end

      if invalid_mappings.any?
        logger.error("Skipped invalid mappings:")

        invalid_mappings.each do |mapping|
          logger.info("  #{mapping}")
        end
      end

      action("Dotfiles pushed", icon: :copy)
    end
  end
end
