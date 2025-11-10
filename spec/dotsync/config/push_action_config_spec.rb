# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::PushActionConfig do
  let(:config_dir) { File.join("/tmp", "dotsync_push_config_spec") }
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
          [push]
          [[push.mappings]]
          src = "#{src_path}"
          dest = "#{dest_path}"
        TOML
      end

      it "loads the configuration successfully" do
        expect { described_class.new(config_path) }.not_to raise_error
      end
    end

    context "with missing push section" do
      before do
        File.write(config_path, <<~TOML)
          [pull]
          [[pull.mappings]]
          src = "path1"
          dest = "path2"
        TOML
      end

      it "raises ConfigError" do
        expect { described_class.new(config_path) }.to raise_error(
          Dotsync::ConfigError,
          /No \[push\] section found in config file/
        )
      end
    end

    context "with missing mappings key" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          other_key = "value"
        TOML
      end

      it "raises ConfigError" do
        expect { described_class.new(config_path) }.to raise_error(
          Dotsync::ConfigError,
          /does not include key 'mappings'/
        )
      end
    end

    context "with mapping missing src key" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          [[push.mappings]]
          dest = "path"
        TOML
      end

      it "raises configuration error" do
        expect { described_class.new(config_path) }.to raise_error(
          /Configuration error in mapping #1.*'src' and 'dest' keys/
        )
      end
    end

    context "with mapping missing dest key" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          [[push.mappings]]
          src = "path"
        TOML
      end

      it "raises configuration error" do
        expect { described_class.new(config_path) }.to raise_error(
          /Configuration error in mapping #1.*'src' and 'dest' keys/
        )
      end
    end

    context "with invalid mapping format (not a hash)" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          mappings = ["invalid"]
        TOML
      end

      it "raises configuration error" do
        expect { described_class.new(config_path) }.to raise_error(
          /Configuration error in mapping #1/
        )
      end
    end
  end

  describe "#mappings" do
    context "with single mapping" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          [[push.mappings]]
          src = "#{src_path}"
          dest = "#{dest_path}"
        TOML
      end

      it "returns array with one Mapping object" do
        config = described_class.new(config_path)
        mappings = config.mappings
        expect(mappings).to be_an(Array)
        expect(mappings.size).to eq(1)
        expect(mappings.first).to be_a(Dotsync::Mapping)
      end

      it "creates mapping with correct src and dest" do
        config = described_class.new(config_path)
        mapping = config.mappings.first
        expect(mapping.src).to include(src_path)
        expect(mapping.dest).to include(dest_path)
      end
    end

    context "with multiple mappings" do
      let(:src_path2) { File.join(config_dir, "src2") }
      let(:dest_path2) { File.join(config_dir, "dest2") }

      before do
        FileUtils.mkdir_p(src_path2)
        FileUtils.mkdir_p(dest_path2)
        File.write(config_path, <<~TOML)
          [push]
          [[push.mappings]]
          src = "#{src_path}"
          dest = "#{dest_path}"

          [[push.mappings]]
          src = "#{src_path2}"
          dest = "#{dest_path2}"
          force = true
        TOML
      end

      it "returns array with multiple Mapping objects" do
        config = described_class.new(config_path)
        mappings = config.mappings
        expect(mappings.size).to eq(2)
        expect(mappings).to all(be_a(Dotsync::Mapping))
      end

      it "preserves mapping attributes" do
        config = described_class.new(config_path)
        mappings = config.mappings
        expect(mappings[0].force?).to be false
        expect(mappings[1].force?).to be true
      end
    end

    context "with mapping containing ignore option" do
      before do
        File.write(config_path, <<~TOML)
          [push]
          [[push.mappings]]
          src = "#{src_path}"
          dest = "#{dest_path}"
          ignore = ["*.log", "tmp/"]
        TOML
      end

      it "creates mapping with ignore patterns" do
        config = described_class.new(config_path)
        mapping = config.mappings.first
        expect(mapping.ignores).to be_an(Array)
        expect(mapping.ignores).not_to be_empty
      end
    end
  end

  describe "SECTION_NAME constant" do
    it "is set to 'push'" do
      expect(described_class.const_get(:SECTION_NAME)).to eq("push")
    end
  end
end
