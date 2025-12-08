# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::WatchActionConfig do
  let(:config_dir) { File.join("/tmp", "dotsync_watch_config_spec") }
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

  describe "inheritance" do
    it "inherits from PushActionConfig" do
      expect(described_class.superclass).to eq(Dotsync::PushActionConfig)
    end
  end

  describe "#initialize" do
    context "with valid configuration" do
      before do
        File.write(config_path, <<~TOML)
          [watch]
          [[watch.mappings]]
          src = "#{src_path}"
          dest = "#{dest_path}"
        TOML
      end

      it "loads the configuration successfully" do
        expect { described_class.new(config_path) }.not_to raise_error
      end
    end

    context "with missing watch section" do
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
          /No \[watch\] mappings or \[\[sync\]\] mappings found in config file/
        )
      end
    end
  end

  describe "#mappings" do
    before do
      File.write(config_path, <<~TOML)
        [watch]
        [[watch.mappings]]
        src = "#{src_path}"
        dest = "#{dest_path}"
      TOML
    end

    it "inherits mappings method from PushActionConfig" do
      config = described_class.new(config_path)
      mappings = config.mappings
      expect(mappings).to be_an(Array)
      expect(mappings.first).to be_a(Dotsync::Mapping)
    end
  end

  describe "SECTION_NAME constant" do
    it "is set to 'watch'" do
      expect(described_class.const_get(:SECTION_NAME)).to eq("watch")
    end
  end

  describe "section_name override" do
    before do
      File.write(config_path, <<~TOML)
        [watch]
        [[watch.mappings]]
        src = "#{src_path}"
        dest = "#{dest_path}"
      TOML
    end

    it "uses watch section instead of push section" do
      config = described_class.new(config_path)
      expect(config.mappings).not_to be_empty
    end
  end
end
