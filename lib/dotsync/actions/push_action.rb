module Dotsync
  class PushAction < BaseAction
    def_delegator :@config, :src
    def_delegator :@config, :dest
    def_delegator :@config, :remove_dest
    def_delegator :@config, :excluded_paths

    def execute
      show_config
      push_dotfiles
    end

    private
      def show_config
        info("Source:", icon: :source)
        info("  #{src}")
        info("Destination:", icon: :dest)
        info("  #{dest}")
        info("Remove destination:", icon: :delete)
        info("  #{remove_dest}")
        if excluded_paths.any?
          info("Excluded paths:", icon: :skip)
          excluded_paths.sort.each { |path| info("  #{path}") }
        end
        info("")
      end

      def push_dotfiles
        Dotsync::FileTransfer.new(@config).transfer
        action("Dotfiles pushed", icon: :copy)
      end
  end
end
