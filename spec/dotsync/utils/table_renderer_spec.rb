# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::TableRenderer do
  describe "#render" do
    it "renders rows as a formatted string" do
      renderer = described_class.new(rows: [["a", "b"], ["c", "d"]])
      result = renderer.render

      expect(result).to be_a(String)
      expect(result).to include("a")
      expect(result).to include("b")
      expect(result).to include("c")
      expect(result).to include("d")
    end

    it "includes headings when provided" do
      renderer = described_class.new(headings: ["Name", "Value"], rows: [["foo", "bar"]])
      result = renderer.render

      expect(result).to include("Name")
      expect(result).to include("Value")
      expect(result).to include("foo")
      expect(result).to include("bar")
    end

    it "exposes rows for inspection" do
      rows = [["x", "y"]]
      renderer = described_class.new(rows: rows)

      expect(renderer.rows).to eq(rows)
    end
  end
end
