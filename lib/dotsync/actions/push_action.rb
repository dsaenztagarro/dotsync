# frozen_string_literal: true

module Dotsync
  class PushAction < BaseAction
    include MappingsTransfer
    include OutputSections

    def execute(options = {})
      output_sections = compute_output_sections(options)

      show_options(options) if output_sections[:options]
      show_env_vars if output_sections[:env_vars]
      show_mappings_legend if output_sections[:mappings_legend]
      show_mappings if output_sections[:mappings]
      show_differences_legend if has_differences? && output_sections[:differences_legend]
      show_differences if output_sections[:differences]

      return unless options[:apply]

      transfer_mappings
      action("Mappings pushed", icon: :done)
    end
  end
end
