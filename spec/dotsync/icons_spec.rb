# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Icons do
  # Reset custom icons before each test to ensure isolation
  before do
    described_class.instance_variable_set(:@custom_icons, {})
  end

  describe "Default icon constants" do
    it "defines INFO icon" do
      expect(described_class::INFO).to be_a(String)
      expect(described_class::INFO).not_to be_empty
    end

    it "defines ERROR icon" do
      expect(described_class::ERROR).to be_a(String)
      expect(described_class::ERROR).not_to be_empty
    end

    it "defines OPTIONS icon" do
      expect(described_class::OPTIONS).to be_a(String)
      expect(described_class::OPTIONS).not_to be_empty
    end

    it "defines ENV_VARS icon" do
      expect(described_class::ENV_VARS).to be_a(String)
      expect(described_class::ENV_VARS).not_to be_empty
    end

    it "defines LEGEND icon" do
      expect(described_class::LEGEND).to be_a(String)
      expect(described_class::LEGEND).not_to be_empty
    end

    it "defines CONFIG icon" do
      expect(described_class::CONFIG).to be_a(String)
      expect(described_class::CONFIG).not_to be_empty
    end

    it "defines DIFF icon" do
      expect(described_class::DIFF).to be_a(String)
      expect(described_class::DIFF).not_to be_empty
    end

    it "defines DEFAULT_FORCE icon" do
      expect(described_class::DEFAULT_FORCE).to be_a(String)
      expect(described_class::DEFAULT_FORCE).not_to be_empty
    end

    it "defines DEFAULT_ONLY icon" do
      expect(described_class::DEFAULT_ONLY).to be_a(String)
      expect(described_class::DEFAULT_ONLY).not_to be_empty
    end

    it "defines DEFAULT_IGNORE icon" do
      expect(described_class::DEFAULT_IGNORE).to be_a(String)
      expect(described_class::DEFAULT_IGNORE).not_to be_empty
    end

    it "defines DEFAULT_INVALID icon" do
      expect(described_class::DEFAULT_INVALID).to be_a(String)
      expect(described_class::DEFAULT_INVALID).not_to be_empty
    end

    it "defines DEFAULT_DIFF_CREATED icon" do
      expect(described_class::DEFAULT_DIFF_CREATED).to be_a(String)
      expect(described_class::DEFAULT_DIFF_CREATED).not_to be_empty
    end

    it "defines DEFAULT_DIFF_UPDATED icon" do
      expect(described_class::DEFAULT_DIFF_UPDATED).to be_a(String)
      expect(described_class::DEFAULT_DIFF_UPDATED).not_to be_empty
    end

    it "defines DEFAULT_DIFF_REMOVED icon" do
      expect(described_class::DEFAULT_DIFF_REMOVED).to be_a(String)
      expect(described_class::DEFAULT_DIFF_REMOVED).not_to be_empty
    end

    it "defines action icons" do
      expect(described_class::PULL).to be_a(String)
      expect(described_class::PULL).not_to be_empty
      expect(described_class::PUSH).to be_a(String)
      expect(described_class::PUSH).not_to be_empty
      expect(described_class::WATCH).to be_a(String)
      expect(described_class::WATCH).not_to be_empty
    end

    it "defines utility icons" do
      expect(described_class::CONSOLE).to be_a(String)
      expect(described_class::CONSOLE).not_to be_empty
      expect(described_class::LISTEN).to be_a(String)
      expect(described_class::LISTEN).not_to be_empty
      expect(described_class::SOURCE).to be_a(String)
      expect(described_class::SOURCE).not_to be_empty
      expect(described_class::DEST).to be_a(String)
      expect(described_class::DEST).not_to be_empty
      expect(described_class::BELL).to be_a(String)
      expect(described_class::BELL).not_to be_empty
      expect(described_class::COPY).to be_a(String)
      expect(described_class::COPY).not_to be_empty
      expect(described_class::SKIP).to be_a(String)
      expect(described_class::SKIP).not_to be_empty
      expect(described_class::DONE).to be_a(String)
      expect(described_class::DONE).not_to be_empty
      expect(described_class::BACKUP).to be_a(String)
      expect(described_class::BACKUP).not_to be_empty
    end
  end

  describe ".load_custom_icons" do
    context "with empty config" do
      it "uses default icons" do
        described_class.load_custom_icons({})

        expect(described_class.force).to eq(described_class::DEFAULT_FORCE)
        expect(described_class.only).to eq(described_class::DEFAULT_ONLY)
        expect(described_class.ignore).to eq(described_class::DEFAULT_IGNORE)
        expect(described_class.invalid).to eq(described_class::DEFAULT_INVALID)
        expect(described_class.diff_created).to eq(described_class::DEFAULT_DIFF_CREATED)
        expect(described_class.diff_updated).to eq(described_class::DEFAULT_DIFF_UPDATED)
        expect(described_class.diff_removed).to eq(described_class::DEFAULT_DIFF_REMOVED)
      end
    end

    context "with nil config" do
      it "handles nil gracefully and uses defaults" do
        described_class.load_custom_icons(nil)

        expect(described_class.force).to eq(described_class::DEFAULT_FORCE)
        expect(described_class.only).to eq(described_class::DEFAULT_ONLY)
      end
    end

    context "with partial custom icons" do
      let(:config) do
        {
          "icons" => {
            "force" => "🔥",
            "diff_created" => "✨"
          }
        }
      end

      it "uses custom icons where provided and defaults for others" do
        described_class.load_custom_icons(config)

        expect(described_class.force).to eq("🔥")
        expect(described_class.diff_created).to eq("✨")
        expect(described_class.only).to eq(described_class::DEFAULT_ONLY)
        expect(described_class.ignore).to eq(described_class::DEFAULT_IGNORE)
        expect(described_class.invalid).to eq(described_class::DEFAULT_INVALID)
        expect(described_class.diff_updated).to eq(described_class::DEFAULT_DIFF_UPDATED)
        expect(described_class.diff_removed).to eq(described_class::DEFAULT_DIFF_REMOVED)
      end
    end

    context "with all custom icons" do
      let(:config) do
        {
          "icons" => {
            "force" => "⚡",
            "only" => "📋",
            "ignore" => "🚫",
            "invalid" => "❌",
            "diff_created" => "✨",
            "diff_updated" => "📝",
            "diff_removed" => "🗑️"
          }
        }
      end

      it "uses all custom icons" do
        described_class.load_custom_icons(config)

        expect(described_class.force).to eq("⚡")
        expect(described_class.only).to eq("📋")
        expect(described_class.ignore).to eq("🚫")
        expect(described_class.invalid).to eq("❌")
        expect(described_class.diff_created).to eq("✨")
        expect(described_class.diff_updated).to eq("📝")
        expect(described_class.diff_removed).to eq("🗑️")
      end
    end

    context "with empty string icons" do
      let(:config) do
        {
          "icons" => {
            "force" => "",
            "ignore" => ""
          }
        }
      end

      it "uses empty strings when explicitly set" do
        described_class.load_custom_icons(config)

        expect(described_class.force).to eq("")
        expect(described_class.ignore).to eq("")
      end
    end
  end

  describe "Icon accessor methods" do
    context "without custom icons loaded" do
      it ".force returns default" do
        expect(described_class.force).to eq(described_class::DEFAULT_FORCE)
      end

      it ".only returns default" do
        expect(described_class.only).to eq(described_class::DEFAULT_ONLY)
      end

      it ".ignore returns default" do
        expect(described_class.ignore).to eq(described_class::DEFAULT_IGNORE)
      end

      it ".invalid returns default" do
        expect(described_class.invalid).to eq(described_class::DEFAULT_INVALID)
      end

      it ".diff_created returns default" do
        expect(described_class.diff_created).to eq(described_class::DEFAULT_DIFF_CREATED)
      end

      it ".diff_updated returns default" do
        expect(described_class.diff_updated).to eq(described_class::DEFAULT_DIFF_UPDATED)
      end

      it ".diff_removed returns default" do
        expect(described_class.diff_removed).to eq(described_class::DEFAULT_DIFF_REMOVED)
      end
    end

    context "with custom icons loaded" do
      before do
        described_class.load_custom_icons({
          "icons" => {
            "force" => "⚡",
            "only" => "📋",
            "ignore" => "🚫",
            "invalid" => "❌",
            "diff_created" => "✨",
            "diff_updated" => "📝",
            "diff_removed" => "🗑️"
          }
        })
      end

      it ".force returns custom icon" do
        expect(described_class.force).to eq("⚡")
      end

      it ".only returns custom icon" do
        expect(described_class.only).to eq("📋")
      end

      it ".ignore returns custom icon" do
        expect(described_class.ignore).to eq("🚫")
      end

      it ".invalid returns custom icon" do
        expect(described_class.invalid).to eq("❌")
      end

      it ".diff_created returns custom icon" do
        expect(described_class.diff_created).to eq("✨")
      end

      it ".diff_updated returns custom icon" do
        expect(described_class.diff_updated).to eq("📝")
      end

      it ".diff_removed returns custom icon" do
        expect(described_class.diff_removed).to eq("🗑️")
      end
    end
  end

  describe "MAPPINGS constant" do
    it "includes all icon mappings" do
      expect(described_class::MAPPINGS).to be_a(Hash)
      expect(described_class::MAPPINGS).to include(
        :info, :error, :env_vars, :options, :legend, :config, :diff,
        :force, :ignore, :pull, :push, :watch, :console, :listen,
        :source, :dest, :bell, :copy, :skip, :done, :backup
      )
    end

    it "has callable force icon" do
      expect(described_class::MAPPINGS[:force]).to be_a(Proc)
      expect(described_class::MAPPINGS[:force].call).to eq(described_class::DEFAULT_FORCE)
    end

    it "has callable ignore icon" do
      expect(described_class::MAPPINGS[:ignore]).to be_a(Proc)
      expect(described_class::MAPPINGS[:ignore].call).to eq(described_class::DEFAULT_IGNORE)
    end

    it "has static icon values for non-configurable icons" do
      expect(described_class::MAPPINGS[:info]).to eq(described_class::INFO)
      expect(described_class::MAPPINGS[:error]).to eq(described_class::ERROR)
      expect(described_class::MAPPINGS[:pull]).to eq(described_class::PULL)
    end
  end

  describe "Icon state isolation between tests" do
    it "resets custom icons properly" do
      # Load custom icons
      described_class.load_custom_icons({
        "icons" => { "force" => "🔥" }
      })
      expect(described_class.force).to eq("🔥")

      # Reset (simulating before hook)
      described_class.instance_variable_set(:@custom_icons, {})

      # Should return to default
      expect(described_class.force).to eq(described_class::DEFAULT_FORCE)
    end
  end
end
