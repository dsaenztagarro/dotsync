# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::FileTransfer do
  let(:config) do
    Dotsync::Mapping.new(
      "src" => src,
      "dest" => dest,
      "force" => force,
      "only" => only,
      "ignore" => ignore
    )
  end
  let(:force) { false }
  let(:only) { [] }
  let(:ignore) { [] }

  let(:subject) { described_class.new(config) }

  describe "#transfer" do
    context "when source is a folder" do
      let(:root) { File.join("/tmp", "dotsync") }
      let(:src) { File.join(root, "src") }
      let(:dest) { File.join(root, "dest") }

      before do
        FileUtils.mkdir_p(src)
        FileUtils.mkdir_p(dest)
      end

      after do
        FileUtils.rm_rf(root)
      end

      it "transfers file in destination" do
        FileUtils.touch(File.join(src, "testfile"))

        subject.transfer

        expect(File.exist?(File.join(dest, "testfile"))).to be true
      end

      context "when file exist in destination" do
        before do
          File.write(File.join(src, "testfile"), "source content")
          File.write(File.join(dest, "testfile"), "destination content")
        end

        it "replaces the file with the source version" do
          subject.transfer

          file_path = File.join(dest, "testfile")
          expect(File.exist?(file_path)).to be true
          expect(File.read(file_path)).to eq("source content")
        end
      end

      context "when folder exist in destination" do
        before do
          FileUtils.mkdir_p(File.join(src, "folder/subfolder1"))
          FileUtils.mkdir_p(File.join(dest, "folder/subfolder2"))
          File.write(File.join(src, "folder/subfolder1", "file1.txt"), "source content")
          File.write(File.join(dest, "folder/subfolder2", "file2.txt"), "destination content")
        end

        it "replaces the folder with the source version" do
          subject.transfer

          folder_path = File.join(dest, "folder/subfolder1")
          File.join(dest, "folder")
          expect(Dir.exist?(folder_path)).to be true
          expect(File.read(File.join(folder_path, "file1.txt"))).to eq("source content")
        end
      end

      context "with ignore paths" do
        let(:ignore) do
          [
            "folder2",
            "folder3/subfolder2",
            "folder3/subfolder3/sub2folder2",
            "file7.txt"
          ]
        end

        before do
          build_file_structure(src)
          FileUtils.mkdir_p(dest)
        end

        it "excludes specified paths from files_to_copy including 3 subfolder levels" do
          subject.transfer

          expect(File.exist?(File.join(dest, "folder1", "file1.txt"))).to be true
          expect(File.exist?(File.join(dest, "folder2", "file2.txt"))).to be false
          expect(File.exist?(File.join(dest, "folder3", "subfolder1", "file3.txt"))).to be true
          expect(File.exist?(File.join(dest, "folder3", "subfolder2", "file4.txt"))).to be false
          expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder1", "file5.txt"))).to be true
          expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder2", "file6.txt"))).to be false
          expect(File.exist?(File.join(dest, "file7.txt"))).to be false
          expect(File.exist?(File.join(dest, "file8.txt"))).to be true
        end

        context "with excluded paths for dotfiles and dotfolders inside normal folders" do
          let(:ignore) do
            [
              "normal_folder/.dotfile_in_folder",
              "normal_folder/.dotfolder_in_folder"
            ]
          end

          before do
            FileUtils.mkdir_p(File.join(src, "normal_folder"))
            File.write(File.join(src, "normal_folder/.dotfile_in_folder"), "dotfile in folder content")
            FileUtils.mkdir_p(File.join(src, "normal_folder/.dotfolder_in_folder"))
            File.write(File.join(src, "normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt"), "file in dotfolder content")
            File.write(File.join(src, "normal_folder/regular_file_in_folder.txt"), "regular file in folder content")
          end

          it "excludes dotfiles and dotfolders inside normal folders from files_to_copy" do
            subject.transfer

            expect(File.exist?(File.join(dest, "normal_folder/.dotfile_in_folder"))).to be false
            expect(File.exist?(File.join(dest, "normal_folder/.dotfolder_in_folder"))).to be false
            expect(File.exist?(File.join(dest, "normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt"))).to be false
            expect(File.exist?(File.join(dest, "normal_folder/regular_file_in_folder.txt"))).to be true
          end
        end

        context "with force option" do
          let(:force) { true }
          let(:ignore) do
            [
              "folder2/file2.txt",
              "folder3/subfolder2",
              "folder3/subfolder3/sub2folder1/file5.txt",
              "file7.txt"
            ]
          end

          before do
            FileUtils.rm_rf(src)
            FileUtils.mkdir_p(src)
            build_file_structure(dest)
          end

          it "ignores files on destination" do
            subject.transfer

            # Ignored files
            expect(File.exist?(File.join(dest, "folder2", "file2.txt"))).to be true
            expect(File.exist?(File.join(dest, "folder3", "subfolder2", "file4.txt"))).to be true
            expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder1", "file5.txt"))).to be true
            expect(File.exist?(File.join(dest, "file7.txt"))).to be true

            # Files removed because they don't exist anymore on source
            expect(File.exist?(File.join(dest, "folder1", "file1.txt"))).to be false
            expect(File.exist?(File.join(dest, "folder3", "subfolder1", "file3.txt"))).to be false
            expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder2", "file6.txt"))).to be false
            expect(File.exist?(File.join(dest, "file8.txt"))).to be false
          end
        end
      end

      context "with only paths" do
        let(:only) do
          [
            "folder1",
            "folder3/subfolder1",
            "folder3/subfolder3/sub2folder1",
            "file8.txt"
          ]
        end

        before do
          build_file_structure(src)
          FileUtils.mkdir_p(dest)
        end

        it "includes only specified paths in files_to_copy" do
          subject.transfer

          expect(File.exist?(File.join(dest, "folder1", "file1.txt"))).to be true
          expect(File.exist?(File.join(dest, "folder2", "file2.txt"))).to be false
          expect(File.exist?(File.join(dest, "folder3", "subfolder1", "file3.txt"))).to be true
          expect(File.exist?(File.join(dest, "folder3", "subfolder2", "file4.txt"))).to be false
          expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder1", "file5.txt"))).to be true
          expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder2", "file6.txt"))).to be false
          expect(File.exist?(File.join(dest, "file7.txt"))).to be false
          expect(File.exist?(File.join(dest, "file8.txt"))).to be true
        end

        context "with excluded paths for dotfiles and dotfolders inside normal folders" do
          let(:only) do
            [
              "normal_folder/.dotfile_in_folder",
              "normal_folder/.dotfolder_in_folder"
            ]
          end

          before do
            FileUtils.mkdir_p(File.join(src, "normal_folder"))
            File.write(File.join(src, "normal_folder/.dotfile_in_folder"), "dotfile in folder content")
            FileUtils.mkdir_p(File.join(src, "normal_folder/.dotfolder_in_folder"))
            File.write(File.join(src, "normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt"), "file in dotfolder content")
          end

          it "excludes dotfiles and dotfolders inside normal folders from files_to_copy" do
            subject.transfer

            expect(File.exist?(File.join(dest, "normal_folder/.dotfile_in_folder"))).to be true
            expect(File.exist?(File.join(dest, "normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt"))).to be true
          end
        end

        context "with ignore and force options" do
          let(:force) { true }
          let(:ignore) do
            [
              "folder2/file2.txt",
              "folder3/subfolder2",
              "folder3/subfolder3/sub2folder1/file5.txt",
              "file7.txt"
            ]
          end

          before do
            build_file_structure(dest)
          end

          it "ignores files on destination" do
            subject.transfer

            # Path included both in "only" and "ignore" options
            # "ignore" option takes precedence
            expect(File.read(File.join(dest, "folder3", "subfolder3", "sub2folder1", "file5.txt"))).to eq("dest content")

            # Paths included in "ignore" option
            expect(File.read(File.join(dest, "folder2", "file2.txt"))).to eq("dest content")
            expect(File.read(File.join(dest, "folder3", "subfolder2", "file4.txt"))).to eq("dest content")
            expect(File.read(File.join(dest, "file7.txt"))).to eq("dest content")

            # Paths not included in "only" option
            # expect(File.read(File.join(dest, "folder3", "subfolder3", "sub2folder2", "file6.txt"))).to eq("dest content")
            expect(File.exist?(File.join(dest, "folder3", "subfolder3", "sub2folder2", "file6.txt"))).to be false

            # Paths included in "only" option
            expect(File.read(File.join(dest, "folder1", "file1.txt"))).to eq("src content")
            expect(File.read(File.join(dest, "folder3", "subfolder1", "file3.txt"))).to eq("src content")
            expect(File.read(File.join(dest, "file8.txt"))).to eq("src content")
          end
        end
      end
    end
  end

  context "when source is a file" do
    let(:root) { File.join("/tmp", "dotsync") }
    let(:src_folder) { File.join(root, "src") }
    let(:dest_folder) { File.join(root, "dest") }
    let(:src) { File.join(src_folder, "src_file") }
    let(:ignore) { [] }

    before do
      FileUtils.mkdir_p(src_folder)
      FileUtils.mkdir_p(dest_folder)
      File.write(src, "source file content")
    end

    after { FileUtils.rm_rf(root) }

    context "when destination is a folder" do
      let(:dest) { dest_folder }

      it "creates the destination file with the source file" do
        subject.transfer

        dest_file = File.join(dest, "src_file")
        expect(File.exist?(dest_file)).to be true
        expect(File.read(dest_file)).to eq("source file content")
      end
    end

    context "when destination is a file" do
      let(:dest) { File.join(dest_folder, "dest_file") }

      context "and the file exist" do
        before do
          File.write(dest, "destination file content")
        end

        it "replaces the destination file with the source file" do
          subject.transfer

          expect(File.exist?(dest)).to be true
          expect(File.read(dest)).to eq("source file content")
        end
      end

      context "and the file does not exist" do
        it "creates the destination file from the source file" do
          subject.transfer

          expect(File.exist?(dest)).to be true
          expect(File.read(dest)).to eq("source file content")
        end
      end
    end
  end

  private
    def build_file_structure(origin)
      origin_basename = File.basename(origin)

      FileUtils.mkdir_p(File.join(origin, "folder1"))
      FileUtils.mkdir_p(File.join(origin, "folder2"))
      FileUtils.mkdir_p(File.join(origin, "folder3", "subfolder1"))
      FileUtils.mkdir_p(File.join(origin, "folder3", "subfolder2"))
      FileUtils.mkdir_p(File.join(origin, "folder3", "subfolder3", "sub2folder1"))
      FileUtils.mkdir_p(File.join(origin, "folder3", "subfolder3", "sub2folder2"))

      File.write(File.join(origin, "folder1", "file1.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "folder2", "file2.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "folder3", "subfolder1", "file3.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "folder3", "subfolder2", "file4.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "folder3", "subfolder3", "sub2folder1", "file5.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "folder3", "subfolder3", "sub2folder2", "file6.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "file7.txt"), "#{origin_basename} content")
      File.write(File.join(origin, "file8.txt"), "#{origin_basename} content")
    end
end
