# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Dotsync::ConfigMerger do
  let(:config_dir) { File.join("/tmp", "dotsync_merger_spec") }
  let(:overlay_path) { File.join(config_dir, "overlay.toml") }
  let(:base_path) { File.join(config_dir, "base.toml") }

  before do
    FileUtils.mkdir_p(config_dir)
  end

  after do
    FileUtils.rm_rf(config_dir)
  end

  describe ".resolve" do
    it "delegates to an instance" do
      config = { "key" => "value" }
      expect(described_class.resolve(config, overlay_path)).to eq(config)
    end
  end

  describe "#resolve" do
    context "when no include key is present" do
      it "returns config unchanged" do
        config = { "sync" => { "home" => [{ "path" => ".zshenv" }] } }
        merger = described_class.new(config, overlay_path)
        expect(merger.resolve).to eq(config)
      end

      it "sets include_path to nil" do
        config = { "key" => "value" }
        merger = described_class.new(config, overlay_path)
        merger.resolve
        expect(merger.include_path).to be_nil
      end
    end

    context "with array concatenation" do
      before do
        File.write(base_path, <<~TOML)
          [[sync.home]]
          path = ".zshenv"

          [[sync.home]]
          path = "Library/LaunchAgents"
        TOML
      end

      it "concatenates arrays from base and overlay" do
        config = {
          "include" => "base.toml",
          "sync" => { "home" => [{ "path" => "Scripts" }] }
        }
        merger = described_class.new(config, overlay_path)
        result = merger.resolve

        expect(result["sync"]["home"]).to eq([
          { "path" => ".zshenv" },
          { "path" => "Library/LaunchAgents" },
          { "path" => "Scripts" }
        ])
      end
    end

    context "with hash deep merge" do
      before do
        File.write(base_path, <<~TOML)
          [watch]
          src = "~/.config"
          dest = "~/Code/dotfiles/src/"
          paths = ["~/.config/nvim/"]
        TOML
      end

      it "deep merges hashes with overlay winning on leaves" do
        config = {
          "include" => "base.toml",
          "watch" => { "dest" => "~/other/path/", "extra" => true }
        }
        merger = described_class.new(config, overlay_path)
        result = merger.resolve

        expect(result["watch"]["src"]).to eq("~/.config")
        expect(result["watch"]["dest"]).to eq("~/other/path/")
        expect(result["watch"]["extra"]).to be true
      end
    end

    context "with include key consumption" do
      before do
        File.write(base_path, <<~TOML)
          [watch]
          src = "~/.config"
        TOML
      end

      it "removes the include key from merged result" do
        config = { "include" => "base.toml" }
        merger = described_class.new(config, overlay_path)
        result = merger.resolve

        expect(result).not_to have_key("include")
      end
    end

    context "with relative path resolution" do
      before do
        File.write(base_path, <<~TOML)
          [section]
          key = "value"
        TOML
      end

      it "resolves path relative to config file directory" do
        config = { "include" => "base.toml" }
        merger = described_class.new(config, overlay_path)
        merger.resolve

        expect(merger.include_path).to eq(base_path)
      end
    end

    context "when include file is missing" do
      it "raises ConfigError" do
        config = { "include" => "nonexistent.toml" }
        merger = described_class.new(config, overlay_path)

        expect { merger.resolve }.to raise_error(
          Dotsync::ConfigError,
          /Included file not found/
        )
      end
    end

    context "when chained includes are present" do
      before do
        File.write(base_path, <<~TOML)
          include = "another.toml"

          [section]
          key = "value"
        TOML
      end

      it "raises ConfigError" do
        config = { "include" => "base.toml" }
        merger = described_class.new(config, overlay_path)

        expect { merger.resolve }.to raise_error(
          Dotsync::ConfigError,
          /Chained includes are not supported/
        )
      end
    end

    context "when include value is not a string" do
      it "raises ConfigError for integer" do
        config = { "include" => 42 }
        merger = described_class.new(config, overlay_path)

        expect { merger.resolve }.to raise_error(
          Dotsync::ConfigError,
          /must be a string path/
        )
      end

      it "raises ConfigError for array" do
        config = { "include" => ["file1.toml", "file2.toml"] }
        merger = described_class.new(config, overlay_path)

        expect { merger.resolve }.to raise_error(
          Dotsync::ConfigError,
          /must be a string path/
        )
      end
    end

    context "with base-only and overlay-only keys" do
      before do
        File.write(base_path, <<~TOML)
          [base_section]
          key = "from_base"
        TOML
      end

      it "preserves keys from both base and overlay" do
        config = {
          "include" => "base.toml",
          "overlay_section" => { "key" => "from_overlay" }
        }
        merger = described_class.new(config, overlay_path)
        result = merger.resolve

        expect(result["base_section"]["key"]).to eq("from_base")
        expect(result["overlay_section"]["key"]).to eq("from_overlay")
      end
    end

    context "when overlay is empty except for include" do
      before do
        File.write(base_path, <<~TOML)
          [[sync.home]]
          path = ".zshenv"

          [watch]
          src = "~/.config"
        TOML
      end

      it "returns base config content" do
        config = { "include" => "base.toml" }
        merger = described_class.new(config, overlay_path)
        result = merger.resolve

        expected = TomlRB.load_file(base_path)
        expect(result).to eq(expected)
      end
    end

    context "include_path accessor" do
      before do
        File.write(base_path, <<~TOML)
          [section]
          key = "value"
        TOML
      end

      it "returns resolved path when include is present" do
        config = { "include" => "base.toml" }
        merger = described_class.new(config, overlay_path)
        merger.resolve

        expect(merger.include_path).to eq(base_path)
      end

      it "returns nil when no include" do
        config = { "key" => "value" }
        merger = described_class.new(config, overlay_path)
        merger.resolve

        expect(merger.include_path).to be_nil
      end
    end

    context "with scalars" do
      before do
        File.write(base_path, <<~TOML)
          [settings]
          name = "base_name"
          count = 5
          enabled = false
        TOML
      end

      it "overlay scalars win over base" do
        config = {
          "include" => "base.toml",
          "settings" => { "name" => "overlay_name", "enabled" => true }
        }
        merger = described_class.new(config, overlay_path)
        result = merger.resolve

        expect(result["settings"]["name"]).to eq("overlay_name")
        expect(result["settings"]["count"]).to eq(5)
        expect(result["settings"]["enabled"]).to be true
      end
    end
  end
end
