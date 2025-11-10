# frozen_string_literal: true

module Dotsync
  module Colors
    DEFAULT_DIFF_ADDITIONS = 34
    DEFAULT_DIFF_MODIFICATIONS = 36
    DEFAULT_DIFF_REMOVALS = 88

    @custom_colors = {}

    def self.load_custom_colors(config)
      config ||= {}
      @custom_colors = {
        diff_additions: config.dig("colors", "diff_additions") || DEFAULT_DIFF_ADDITIONS,
        diff_modifications: config.dig("colors", "diff_modifications") || DEFAULT_DIFF_MODIFICATIONS,
        diff_removals: config.dig("colors", "diff_removals") || DEFAULT_DIFF_REMOVALS
      }
    end

    def self.diff_additions
      @custom_colors[:diff_additions] || DEFAULT_DIFF_ADDITIONS
    end

    def self.diff_modifications
      @custom_colors[:diff_modifications] || DEFAULT_DIFF_MODIFICATIONS
    end

    def self.diff_removals
      @custom_colors[:diff_removals] || DEFAULT_DIFF_REMOVALS
    end

    MAPPINGS = {
      diff_additions: -> { diff_additions },
      diff_modifications: -> { diff_modifications },
      diff_removals: -> { diff_removals }
    }
  end
end
