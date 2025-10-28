# frozen_string_literal: true

module Dotsync
  # Represents the differences between two directories
  class Diff
    attr_reader :additions, :modifications, :removals

    def initialize(additions: [], modifications: [], removals: [])
      @additions = additions
      @modifications = modifications
      @removals = removals
    end

    def empty?
      @additions.empty? && @modifications.empty? && @removals.empty?
    end
  end
end
