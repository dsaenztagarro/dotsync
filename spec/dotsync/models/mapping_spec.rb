# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Mapping do
  include Dotsync::PathUtils

  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:force) { false }
  let(:ignore) { [] }
  let(:only) { [] }
  let(:attributes) do
    {
      "src" => src,
      "dest" => dest,
      "force" => force,
      "only" => only,
      "ignore" => ignore
    }
  end

  subject(:mapping_entry) { described_class.new(attributes) }

  after do
    FileUtils.rm_rf(root)
  end

  describe "#src" do
    it "returns the sanitized expanded source path" do
      expect(mapping_entry.src).to eq(sanitize_path(src))
    end
  end

  describe "#dest" do
    it "returns the sanitized expanded destination path" do
      expect(mapping_entry.dest).to eq(sanitize_path(dest))
    end
  end

  describe "#force?" do
    context "without attribute force" do
      let(:attributes) { { "src" => src, "dest" => dest } }

      it "returns false by default" do
        expect(mapping_entry.force?).to be false
      end
    end

    context "with attribute force" do
      let(:force) { true }

      it "returns true" do
        expect(mapping_entry.force?).to be true
      end
    end
  end

  describe "#ignores" do
    context "without ignore attribute" do
      let(:attributes) { { "src" => src, "dest" => dest } }

      it "returns false by default" do
        expect(mapping_entry.ignores).to eq([])
      end
    end

    context "with ignore attribute" do
      let(:ignored_file) { File.join(src, "ignored_file") }
      let(:ignored_folder) { File.join(src, "ignored_folder") }
      let(:ignore) { ["ignored_file", "ignored_folder"] }

      it "returns the sanitized expanded paths of ignored files/folders" do
        expect(mapping_entry.ignores).to include(
          sanitize_path(ignored_file),
          sanitize_path(ignored_folder)
        )
      end
    end
  end

  describe "#valid?" do
    context "when both src and dest are files" do
      before do
        FileUtils.mkdir_p(root)
        FileUtils.touch(src)
        FileUtils.touch(dest)
      end

      it "returns true" do
        expect(mapping_entry.valid?).to be true
      end

      context "and dest file does not exist" do
        before do
          FileUtils.rm(dest)
        end

        it "returns true" do
          expect(mapping_entry.valid?).to be true
        end
      end
    end

    context "when both src and dest are directories" do
      before do
        FileUtils.mkdir_p(src)
        FileUtils.mkdir_p(dest)
      end

      it "returns true" do
        expect(mapping_entry.valid?).to be true
      end
    end

    context "when src does not exist" do
      before do
        FileUtils.mkdir_p(dest)
      end

      it "returns false" do
        expect(mapping_entry.valid?).to be false
      end
    end

    context "when dest does not exist" do
      before do
        FileUtils.mkdir_p(src)
      end

      it "returns false" do
        expect(mapping_entry.valid?).to be false
      end
    end
  end

  describe "#decorated_src" do
    let(:subject) { mapping_entry.decorated_src }

    context "when contains env var" do
      let(:root) { "$HOME" }
      let(:color) { 104 }

      before do
        ENV["HOME"] = File.join("/tmp", "dotsync")
      end

      it "returns colorized env var" do
        expect(subject).to include("\e[38;5;#{color}m$HOME\e[0m/src")
      end
    end
  end

  describe "#icons" do
    let(:subject) { mapping_entry.icons }

    before do
      FileUtils.mkdir_p(src)
      FileUtils.mkdir_p(dest)
    end

    it "returns an empty string without icons" do
      expect(subject).to eq("")
    end

    context "when force is enabled" do
      let(:force) { true }

      it "returns a formatted string with force icon" do
        expect(subject).to include(Dotsync::Icons.force)
        expect(subject).to_not include(Dotsync::Icons.ignore)
        expect(subject).to_not include(Dotsync::Icons.invalid)
      end
    end

    context "when ignores is set" do
      let(:ignore) { ["ignored_file"] }

      it "returns a formatted string with ignore icon" do
        expect(subject).to include(Dotsync::Icons.ignore)
        expect(subject).to_not include(Dotsync::Icons.force)
        expect(subject).to_not include(Dotsync::Icons.invalid)
      end
    end

    context "when mapping is invalid" do
      before do
        FileUtils.rm_rf(root)
      end

      it "returns a formatted string with invalid icon" do
        expect(subject).to include(Dotsync::Icons.invalid)
        expect(subject).to_not include(Dotsync::Icons.ignore)
        expect(subject).to_not include(Dotsync::Icons.force)
      end
    end
  end

  describe "#backup_possible?" do
    context "when valid and dest exists" do
      before do
        FileUtils.mkdir_p(src)
        FileUtils.mkdir_p(dest)
      end

      it "returns true" do
        expect(mapping_entry.backup_possible?).to be true
      end
    end

    context "when valid but dest does not exist" do
      before { FileUtils.rm_rf(dest) }

      it "returns false" do
        expect(mapping_entry.backup_possible?).to be false
      end
    end

    context "when invalid" do
      before { FileUtils.rm_rf(src) }

      it "returns false" do
        expect(mapping_entry.backup_possible?).to be false
      end
    end
  end

  describe "#backup_basename" do
    it "returns nil with invalid mapping" do
      expect(mapping_entry.backup_basename).to be_nil
    end

    context "when dest is file" do
      before do
        FileUtils.mkdir_p(root)
        FileUtils.touch(src)
        FileUtils.touch(dest)
      end

      it "returns the basename of the dest" do
        expect(mapping_entry.backup_basename).to eq(File.basename(dest))
      end

      context "when dest file does not exist" do
        before do
          FileUtils.rm(dest)
        end

        it "returns the basename of parent directory of dest" do
          expect(mapping_entry.backup_basename).to eq(sanitize_path File.dirname(dest))
        end
      end
    end

    context "when dest is directory" do
      before do
        FileUtils.mkdir_p(src)
        FileUtils.mkdir_p(dest)
      end

      it "returns the basename of the dest" do
        expect(mapping_entry.backup_basename).to eq(File.basename(dest))
      end
    end
  end
end
