# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::DirectoryDiffer do
  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:only) { [] }
  let(:ignore) { [] }
  let(:mapping) do
    Dotsync::Mapping.new(
      "src" => mapping_src,
      "dest" => mapping_dest,
      "force" => true,
      "only" => only,
      "ignore" => ignore
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
    context "mapping directories" do
      let(:mapping_src) { src }
      let(:mapping_dest) { dest }

      context "when files are added, modified, and removed" do
        before do
          FileUtils.mkdir_p(File.join(src, "fold"))
          FileUtils.mkdir_p(File.join(dest, "fold"))
          File.write(File.join(src, "fold", "file1.txt"), "new file content")
          File.write(File.join(src, "fold", "file3.txt"), "content")
          File.write(File.join(dest, "fold", "file2.txt"), "old file content")
          File.write(File.join(dest, "fold", "file3.txt"), "different content")
        end

        it "returns a Diff object with correct additions, modifications, and removals" do
          diff = differ.diff

          expect(diff).to be_a(Dotsync::Diff)
          expect(diff.additions).to include(File.join(dest, "fold", "file1.txt"))
          expect(diff.removals).to include(File.join(src, "fold", "file2.txt"))
          expect(diff.modifications).to include(File.join(dest, "fold", "file3.txt"))
        end

        context "with files ignored" do
          let(:ignore) { ["fold/file1.txt", "fold/file2.txt", "fold/file3.txt"] }

          it "returns a Diff without ignored files" do
            diff = differ.diff

            expect(diff).to be_a(Dotsync::Diff)
            expect(diff.additions).to_not include(File.join(dest, "file1.txt"))
            expect(diff.removals).to_not include(File.join(src, "file2.txt"))
            expect(diff.modifications).to_not include(File.join(dest, "file3.txt"))
          end
        end

        context "with only option" do
          context "including a file" do
            let(:only) { [File.join("fold", "file2.txt")] }

            it "returns a Diff object with correct additions, modifications, and removals" do
              diff = differ.diff

              expect(diff).to be_a(Dotsync::Diff)
              expect(diff.additions).to_not include(File.join(dest, "fold", "file1.txt"))
              expect(diff.removals).to include(File.join(src, "fold", "file2.txt"))
              expect(diff.modifications).to_not include(File.join(dest, "fold", "file3.txt"))
            end
          end

          context "including a directory" do
            let(:only) { [File.join("fold")] }

            before do
              FileUtils.mkdir_p(File.join(src, "fold2"))
              File.write(File.join(src, "fold2", "file4.txt"), "content")
            end

            it "returns a Diff object with correct additions, modifications, and removals" do
              diff = differ.diff

              expect(diff).to be_a(Dotsync::Diff)
              expect(diff.additions).to_not include(File.join(dest, "fold2", "file4.txt"))
            end
          end
        end

        context "with ignore option" do
          let(:ignore) { ["fold"] }

          it "returns a Diff without ignored directory" do
            diff = differ.diff

            expect(diff).to be_a(Dotsync::Diff)
            expect(diff.additions).to_not include(File.join(dest, "file1.txt"))
            expect(diff.removals).to_not include(File.join(src, "file2.txt"))
            expect(diff.modifications).to_not include(File.join(dest, "file3.txt"))
          end
        end
      end

      context "when no differences exist" do
        before do
          File.write(File.join(src, "file1.txt"), "content")
          File.write(File.join(dest, "file1.txt"), "content")
        end

        it "returns an empty Diff object" do
          diff = differ.diff

          expect(diff).to be_a(Dotsync::Diff)
          expect(diff.empty?).to be true
        end
      end
    end

    context "mapping files" do
      let(:mapping_src) { File.join(src, "file.txt") }
      let(:mapping_dest) { File.join(dest, "file.txt") }

      context "when files exist only in src" do
        before do
          File.write(File.join(src, "file.txt"), "src content")
        end

        it "returns a Diff with additions" do
          diff = differ.diff

          expect(diff).to be_a(Dotsync::Diff)
          expect(diff.additions).to include(File.join(dest, "file.txt"))
          expect(diff.modifications).to be_empty
          expect(diff.removals).to be_empty
        end
      end

      context "when files exist in src and dest" do
        before do
          File.write(File.join(src, "file.txt"), "src content")
          File.write(File.join(dest, "file.txt"), "dest content")
        end

        it "returns a Diff with modification" do
          diff = differ.diff

          expect(diff).to be_a(Dotsync::Diff)
          expect(diff.additions).to be_empty
          expect(diff.modifications).to include(File.join(dest, "file.txt"))
          expect(diff.removals).to be_empty
        end
      end
    end
  end
end
