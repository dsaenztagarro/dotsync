# frozen_string_literal: true

module Dotsync
  # Represents the differences between two directories
  class Diff
    attr_reader :additions, :modifications, :removals, :modification_pairs

    def initialize(additions: [], modifications: [], removals: [], modification_pairs: [])
      @additions = additions
      @modifications = modifications
      @removals = removals
      @modification_pairs = modification_pairs
    end

    def any?
      @additions.any? || @modifications.any? || @removals.any?
    end

    def empty?
      @additions.empty? && @modifications.empty? && @removals.empty?
    end
  end
end
