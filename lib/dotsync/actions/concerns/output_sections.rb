# frozen_string_literal: true

module Dotsync
  module OutputSections
    def compute_output_sections(options)
      quiet = options[:quiet]
      verbose = options[:verbose]

      output_sections = {
        options: !(quiet || options[:only_diff] || options[:only_mappings]),
        env_vars: !(quiet || options[:only_diff] || options[:only_mappings]),
        mappings_legend: !(quiet || options[:no_legend] || options[:no_mappings] || options[:only_diff]),
        mappings: !(quiet || options[:no_mappings] || options[:only_diff]),
        differences_legend: !(quiet || options[:no_legend] || options[:no_diff_legend] || options[:no_diff] || options[:only_config] || options[:only_mappings]),
        differences: !(quiet || options[:no_diff] || options[:only_mappings] || options[:only_config])
      }

      if verbose
        output_sections.transform_values! { |_| true }
      end

      output_sections
    end
  end
end
