# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Manifest do
  let(:root) { File.join("/tmp", "dotsync_manifest_test") }
  let(:dest_dir) { File.join(root, "dest") }
  let(:xdg_data_home) { File.join(root, "data") }
  let(:key) { "xdg_bin" }
  let(:manifest_path) { File.join(xdg_data_home, "dotsync/manifests/#{key}.json") }

  subject(:manifest) do
    described_class.new(dest_dir: dest_dir, key: key, xdg_data_home: xdg_data_home)
  end

  before do
    FileUtils.mkdir_p(dest_dir)
    FileUtils.mkdir_p(xdg_data_home)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#read" do
    context "when no manifest exists" do
      it "returns an empty array" do
        expect(manifest.read).to eq([])
      end
    end

    context "when manifest exists with files" do
      before do
        FileUtils.mkdir_p(File.dirname(manifest_path))
        File.write(manifest_path, '{"files": ["grafanactl", "elasticctl"]}')
      end

      it "returns the file list" do
        expect(manifest.read).to eq(["grafanactl", "elasticctl"])
      end
    end

    context "when manifest contains invalid JSON" do
      before do
        FileUtils.mkdir_p(File.dirname(manifest_path))
        File.write(manifest_path, "not json")
      end

      it "returns an empty array" do
        expect(manifest.read).to eq([])
      end
    end
  end

  describe "#write" do
    it "creates the manifest directory and writes the file list" do
      manifest.write(["grafanactl", "elasticctl"])

      expect(File.exist?(manifest_path)).to be true
      data = JSON.parse(File.read(manifest_path))
      expect(data["files"]).to eq(["elasticctl", "grafanactl"])
    end

    it "overwrites an existing manifest" do
      manifest.write(["old_file"])
      manifest.write(["new_file"])

      data = JSON.parse(File.read(manifest_path))
      expect(data["files"]).to eq(["new_file"])
    end
  end

  describe "#orphans" do
    before do
      FileUtils.mkdir_p(File.dirname(manifest_path))
      File.write(manifest_path, '{"files": ["setup-grafana", "grafanactl", "elasticctl"]}')
    end

    it "returns absolute paths of files in old manifest but not in current_files" do
      current_files = ["grafanactl", "elasticctl"]
      result = manifest.orphans(current_files)

      expect(result).to eq([File.join(dest_dir, "setup-grafana")])
    end

    it "returns empty array when no orphans exist" do
      current_files = ["setup-grafana", "grafanactl", "elasticctl"]
      result = manifest.orphans(current_files)

      expect(result).to eq([])
    end

    it "returns all previous files as orphans when current_files is empty" do
      result = manifest.orphans([])

      expect(result).to contain_exactly(
        File.join(dest_dir, "setup-grafana"),
        File.join(dest_dir, "grafanactl"),
        File.join(dest_dir, "elasticctl")
      )
    end

    context "when no previous manifest exists" do
      before do
        FileUtils.rm(manifest_path)
      end

      it "returns empty array" do
        result = manifest.orphans(["grafanactl"])
        expect(result).to eq([])
      end
    end
  end
end
