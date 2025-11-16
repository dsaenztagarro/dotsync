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
          expect(diff.removals).to include(File.join(dest, "fold", "file2.txt"))
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
              expect(diff.removals).to include(File.join(dest, "fold", "file2.txt"))
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

          context "including specific files inside folders" do
            let(:only) { ["bundle/config", "ghc/ghci.conf"] }

            before do
              FileUtils.rm_rf(src)
              FileUtils.rm_rf(dest)
              FileUtils.mkdir_p(src)
              FileUtils.mkdir_p(dest)

              # Create files we want to include
              FileUtils.mkdir_p(File.join(src, "bundle"))
              File.write(File.join(src, "bundle/config"), "new bundle config")

              FileUtils.mkdir_p(File.join(src, "ghc"))
              File.write(File.join(src, "ghc/ghci.conf"), "new ghc config")

              # Create other files that should not be included
              File.write(File.join(src, "bundle/other.txt"), "other file")
              FileUtils.mkdir_p(File.join(src, "cabal"))
              File.write(File.join(src, "cabal/config"), "cabal config")

              # Create existing dest files
              FileUtils.mkdir_p(File.join(dest, "bundle"))
              File.write(File.join(dest, "bundle/config"), "old bundle config")
              File.write(File.join(dest, "bundle/obsolete.txt"), "obsolete file")

              FileUtils.mkdir_p(File.join(dest, "cabal"))
              File.write(File.join(dest, "cabal/config"), "old cabal config")
            end

            it "detects additions only for specified files" do
              diff = differ.diff

              expect(diff).to be_a(Dotsync::Diff)

              # Should detect the new ghc config file
              expect(diff.additions).to include(File.join(dest, "ghc/ghci.conf"))

              # Should NOT detect other files as additions
              expect(diff.additions).to_not include(File.join(dest, "bundle/other.txt"))
              expect(diff.additions).to_not include(File.join(dest, "cabal/config"))
            end

            it "detects modifications only for specified files" do
              diff = differ.diff

              expect(diff).to be_a(Dotsync::Diff)

              # Should detect modification of bundle/config
              expect(diff.modifications).to include(File.join(dest, "bundle/config"))

              # Should NOT detect modifications for unrelated files
              expect(diff.modifications).to_not include(File.join(dest, "cabal/config"))
            end

            it "does not detect removals of sibling files in the same directory" do
              diff = differ.diff

              expect(diff).to be_a(Dotsync::Diff)

              # Should NOT detect removal of sibling files
              # (only = ["bundle/config"] means manage only that file, not the whole bundle/ directory)
              expect(diff.removals).to_not include(File.join(dest, "bundle/obsolete.txt"))

              # Should NOT detect removal of cabal/config (unrelated path)
              expect(diff.removals).to_not include(File.join(dest, "cabal/config"))
            end
          end

          context "including deeply nested file paths" do
            let(:only) { ["deep/nested/path/config.yml"] }

            before do
              FileUtils.rm_rf(src)
              FileUtils.rm_rf(dest)
              FileUtils.mkdir_p(src)
              FileUtils.mkdir_p(dest)

              # Create deeply nested file
              FileUtils.mkdir_p(File.join(src, "deep/nested/path"))
              File.write(File.join(src, "deep/nested/path/config.yml"), "nested config")

              # Create sibling files
              File.write(File.join(src, "deep/nested/path/other.yml"), "other config")
              File.write(File.join(src, "deep/nested/sibling.txt"), "sibling file")
            end

            it "detects changes only for the specified nested file" do
              diff = differ.diff

              expect(diff).to be_a(Dotsync::Diff)

              # Should detect addition of the specified nested file
              expect(diff.additions).to include(File.join(dest, "deep/nested/path/config.yml"))

              # Should NOT detect sibling files
              expect(diff.additions).to_not include(File.join(dest, "deep/nested/path/other.yml"))
              expect(diff.additions).to_not include(File.join(dest, "deep/nested/sibling.txt"))
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

        context "when files have same size but different content" do
          before do
            File.write(File.join(src, "file.txt"), "12345")
            File.write(File.join(dest, "file.txt"), "abcde")
          end

          it "detects modification based on content" do
            diff = differ.diff

            expect(diff).to be_a(Dotsync::Diff)
            expect(diff.modifications).to include(File.join(dest, "file.txt"))
          end
        end

        context "when files have same size and same content" do
          before do
            File.write(File.join(src, "file.txt"), "same content")
            File.write(File.join(dest, "file.txt"), "same content")
          end

          it "does not detect modification" do
            diff = differ.diff

            expect(diff).to be_a(Dotsync::Diff)
            expect(diff.modifications).to be_empty
          end
        end
      end
    end
  end
end
