module Dotsync
  module MappingsTransfer
    extend Forwardable # def_delegator

    def_delegator :@config, :mappings

    def show_mappings
      info("Mappings:", icon: :config, )

      mappings.each do |mapping|
        logger.log("  #{mapping}")
      end
    end

    def transfer_mappings
      valid_mappings.each do |mapping|
        Dotsync::FileTransfer.new(mapping).transfer
      end
    end

    def valid_mappings
      mappings.select(&:valid?)
    end
  end
end
