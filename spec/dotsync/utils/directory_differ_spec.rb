# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::DirectoryDiffer do
  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:mapping) do
    Dotsync::Mapping.new(
      "src" => src,
      "dest" => dest,
      "force" => true,
      "ignore" => []
    )
  end
  subject(:differ) { described_class.new(mapping) }

  before do
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#diff" do
    context "when files are added, modified, and removed" do
      it "returns a Diff object with correct additions, modifications, and removals" do
        File.write(File.join(src, "file1.txt"), "new file content")
        File.write(File.join(dest, "file2.txt"), "old file content")
        File.write(File.join(src, "file3.txt"), "content")
        File.write(File.join(dest, "file3.txt"), "different content")

        diff = differ.diff
        expect(diff).to be_a(Dotsync::Diff)
        expect(diff.additions).to include("file1.txt")
        expect(diff.removals).to include("file2.txt")
        expect(diff.modifications).to include("file3.txt")
      end
    end

    context "when no differences exist" do
      it "returns an empty Diff object" do
        File.write(File.join(src, "file1.txt"), "content")
        File.write(File.join(dest, "file1.txt"), "content")
        diff = differ.diff
        expect(diff).to be_a(Dotsync::Diff)
        expect(diff.empty?).to be true
      end
    end
  end
end
