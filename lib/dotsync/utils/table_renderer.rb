# frozen_string_literal: true

require "terminal-table"

module Dotsync
  class TableRenderer
    attr_reader :rows

    def initialize(rows:, headings: nil)
      @rows = rows
      @headings = headings
    end

    def render
      options = { rows: @rows }
      options[:headings] = @headings if @headings
      Terminal::Table.new(**options).to_s
    end
  end
end
