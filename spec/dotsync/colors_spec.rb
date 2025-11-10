# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Colors do
  # Reset custom colors between tests
  before do
    described_class.instance_variable_set(:@custom_colors, {})
  end

  describe ".load_custom_colors" do
    it "loads custom diff colors from config" do
      config = {
        "colors" => {
          "diff_additions" => 32,
          "diff_modifications" => 33,
          "diff_removals" => 31
        }
      }

      described_class.load_custom_colors(config)

      custom_colors = described_class.instance_variable_get(:@custom_colors)
      expect(custom_colors[:diff_additions]).to eq(32)
      expect(custom_colors[:diff_modifications]).to eq(33)
      expect(custom_colors[:diff_removals]).to eq(31)
    end

    it "uses defaults when colors not specified" do
      config = {}

      described_class.load_custom_colors(config)

      custom_colors = described_class.instance_variable_get(:@custom_colors)
      expect(custom_colors[:diff_additions]).to eq(Dotsync::Colors::DEFAULT_DIFF_ADDITIONS)
      expect(custom_colors[:diff_modifications]).to eq(Dotsync::Colors::DEFAULT_DIFF_MODIFICATIONS)
      expect(custom_colors[:diff_removals]).to eq(Dotsync::Colors::DEFAULT_DIFF_REMOVALS)
    end

    it "handles nil config" do
      expect { described_class.load_custom_colors(nil) }.not_to raise_error

      custom_colors = described_class.instance_variable_get(:@custom_colors)
      expect(custom_colors[:diff_additions]).to eq(Dotsync::Colors::DEFAULT_DIFF_ADDITIONS)
    end

    it "handles empty config" do
      described_class.load_custom_colors({})

      custom_colors = described_class.instance_variable_get(:@custom_colors)
      expect(custom_colors[:diff_additions]).to eq(Dotsync::Colors::DEFAULT_DIFF_ADDITIONS)
      expect(custom_colors[:diff_modifications]).to eq(Dotsync::Colors::DEFAULT_DIFF_MODIFICATIONS)
      expect(custom_colors[:diff_removals]).to eq(Dotsync::Colors::DEFAULT_DIFF_REMOVALS)
    end

    it "handles partial custom colors" do
      config = {
        "colors" => {
          "diff_additions" => 42
        }
      }

      described_class.load_custom_colors(config)

      custom_colors = described_class.instance_variable_get(:@custom_colors)
      expect(custom_colors[:diff_additions]).to eq(42)
      expect(custom_colors[:diff_modifications]).to eq(Dotsync::Colors::DEFAULT_DIFF_MODIFICATIONS)
      expect(custom_colors[:diff_removals]).to eq(Dotsync::Colors::DEFAULT_DIFF_REMOVALS)
    end
  end

  describe "color accessors" do
    context "with custom colors loaded" do
      before do
        config = {
          "colors" => {
            "diff_additions" => 32,
            "diff_modifications" => 33,
            "diff_removals" => 31
          }
        }
        described_class.load_custom_colors(config)
      end

      it "returns custom diff_additions color" do
        expect(described_class.diff_additions).to eq(32)
      end

      it "returns custom diff_modifications color" do
        expect(described_class.diff_modifications).to eq(33)
      end

      it "returns custom diff_removals color" do
        expect(described_class.diff_removals).to eq(31)
      end
    end

    context "without custom colors" do
      it "returns default diff_additions color" do
        expect(described_class.diff_additions).to eq(Dotsync::Colors::DEFAULT_DIFF_ADDITIONS)
      end

      it "returns default diff_modifications color" do
        expect(described_class.diff_modifications).to eq(Dotsync::Colors::DEFAULT_DIFF_MODIFICATIONS)
      end

      it "returns default diff_removals color" do
        expect(described_class.diff_removals).to eq(Dotsync::Colors::DEFAULT_DIFF_REMOVALS)
      end
    end
  end

  describe "MAPPINGS constant" do
    it "includes all color mappings" do
      expect(described_class::MAPPINGS).to include(:diff_additions, :diff_modifications, :diff_removals)
    end

    it "has callable lambdas for color access" do
      expect(described_class::MAPPINGS[:diff_additions]).to be_a(Proc)
      expect(described_class::MAPPINGS[:diff_additions].call).to be_a(Integer)
    end
  end

  describe "color state isolation between tests" do
    it "resets custom colors properly" do
      # First test sets custom colors
      config = { "colors" => { "diff_additions" => 99 } }
      described_class.load_custom_colors(config)
      expect(described_class.diff_additions).to eq(99)

      # Reset (simulating before hook)
      described_class.instance_variable_set(:@custom_colors, {})

      # Second test should have defaults
      expect(described_class.diff_additions).to eq(Dotsync::Colors::DEFAULT_DIFF_ADDITIONS)
    end
  end
end
