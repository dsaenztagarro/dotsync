# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::PullActionConfig do
  let(:config_dir) { File.join("/tmp", "dotsync_pull_config_spec") }
  let(:config_path) { File.join(config_dir, "config.toml") }
  let(:src_path) { File.join(config_dir, "src") }
  let(:dest_path) { File.join(config_dir, "dest") }

  before do
    FileUtils.mkdir_p(config_dir)
    FileUtils.mkdir_p(src_path)
    FileUtils.mkdir_p(dest_path)
  end

  after do
    FileUtils.rm_rf(config_dir)
  end

  describe "#initialize" do
    context "with valid configuration" do
      before do
        File.write(config_path, <<~TOML)
          [pull]
          [[pull.mappings]]
          src = "#{src_path}"
          dest = "#{dest_path}"
        TOML
      end

      it "loads the configuration successfully" do
        expect { described_class.new(config_path) }.not_to raise_error
      end
    end

    context "with missing pull section" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          [[push.mappings]]
          src = "path1"
          dest = "path2"
        TOML
      end

      it "raises ConfigError" do
        expect { described_class.new(config_path) }.to raise_error(
          Dotsync::ConfigError,
          /No \[pull\] mappings or \[sync\] mappings found in config file/
        )
      end
    end
  end

  describe "#mappings" do
    before do
      File.write(config_path, <<~TOML)
        [pull]
        [[pull.mappings]]
        src = "#{src_path}"
        dest = "#{dest_path}"
      TOML
    end

    it "returns array of Mapping objects" do
      config = described_class.new(config_path)
      mappings = config.mappings
      expect(mappings).to be_an(Array)
      expect(mappings.first).to be_a(Dotsync::Mapping)
    end
  end

  describe "#backups_root" do
    before do
      File.write(config_path, <<~TOML)
        [pull]
        [[pull.mappings]]
        src = "#{src_path}"
        dest = "#{dest_path}"
      TOML
    end

    it "returns path in XDG data home" do
      config = described_class.new(config_path)
      backups_path = config.backups_root
      expect(backups_path).to include("dotsync")
      expect(backups_path).to include("backups")
    end

    it "includes xdg_data_home directory" do
      config = described_class.new(config_path)
      backups_path = config.backups_root
      xdg_data_home = ENV["XDG_DATA_HOME"] || File.expand_path("~/.local/share")
      expect(backups_path).to start_with(xdg_data_home)
    end
  end

  describe "XDGBaseDirectory inclusion" do
    it "includes XDGBaseDirectory module" do
      expect(described_class.included_modules).to include(Dotsync::XDGBaseDirectory)
    end
  end

  describe "SECTION_NAME constant" do
    it "is set to 'pull'" do
      expect(described_class.const_get(:SECTION_NAME)).to eq("pull")
    end
  end
end
