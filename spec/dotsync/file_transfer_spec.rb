require "spec_helper"

RSpec.describe Dotsync::FileTransfer do
  let(:config) do
    {
      src: src,
      dest: dest,
      force: force,
      excluded_paths: excluded_paths
    }
  end
  let(:force) { false }

  let(:subject) { described_class.new(config) }

  describe '#transfer' do
    context "when source is a folder" do
      let(:src) { '/tmp/dotsync_src' }
      let(:dest) { '/tmp/dotsync_dest' }
      let(:excluded_paths) { [] }

      before do
        FileUtils.mkdir_p(src)
        FileUtils.mkdir_p(dest)
      end

      after do
        FileUtils.rm_rf(src)
        FileUtils.rm_rf(dest)
      end

      it 'transfers file in destination' do
        FileUtils.touch(File.join(src, 'testfile'))

        subject.transfer

        expect(File.exist?(File.join(dest, 'testfile'))).to be true
      end

      context 'when transfered file exist in destination' do
        before do
          File.write(File.join(src, 'testfile'), 'source content')
          File.write(File.join(dest, 'testfile'), 'destination content')
        end

        it 'replaces the file with the source version' do
          subject.transfer

          file_path = File.join(dest, 'testfile')
          expect(File.exist?(file_path)).to be true
          expect(File.read(file_path)).to eq('source content')
        end
      end

      context 'when transfered folder exist in destination' do
        before do
          FileUtils.mkdir_p(File.join(src, 'folder/subfolder1'))
          FileUtils.mkdir_p(File.join(dest, 'folder/subfolder2'))
          File.write(File.join(src, 'folder/subfolder1', 'file1.txt'), 'source content')
          File.write(File.join(dest, 'folder/subfolder2', 'file2.txt'), 'destination content')
        end

        it 'replaces the folder with the source version' do
          subject.transfer

          folder_path = File.join(dest, 'folder/subfolder1')
          removed_path = File.join(dest, 'folder')
          expect(Dir.exist?(folder_path)).to be true
          expect(File.read(File.join(folder_path, 'file1.txt'))).to eq('source content')
        end
      end

      context 'with excluded paths' do
        let(:excluded_paths) do
          [
            File.join(src, 'excluded_folder'),
            File.join(src, 'subfolder/excluded_subfolder'),
            File.join(src, 'subfolder/another_subfolder/excluded_subsubfolder'),
            File.join(src, 'excluded_file.txt')
          ]
        end

        before do
          FileUtils.mkdir_p(File.join(src, 'included_folder'))
          FileUtils.mkdir_p(File.join(src, 'excluded_folder'))
          FileUtils.mkdir_p(File.join(src, 'subfolder', 'included_subfolder'))
          FileUtils.mkdir_p(File.join(src, 'subfolder', 'excluded_subfolder'))
          FileUtils.mkdir_p(File.join(src, 'subfolder', 'another_subfolder', 'included_subsubfolder'))
          FileUtils.mkdir_p(File.join(src, 'subfolder', 'another_subfolder', 'excluded_subsubfolder'))
          File.write(File.join(src, 'included_folder', 'file1.txt'), 'content')
          File.write(File.join(src, 'excluded_folder', 'file2.txt'), 'content')
          File.write(File.join(src, 'subfolder', 'included_subfolder', 'file3.txt'), 'content')
          File.write(File.join(src, 'subfolder', 'excluded_subfolder', 'file4.txt'), 'content')
          File.write(File.join(src, 'subfolder', 'another_subfolder', 'included_subsubfolder', 'file5.txt'), 'content')
          File.write(File.join(src, 'subfolder', 'another_subfolder', 'excluded_subsubfolder', 'file6.txt'), 'content')
          File.write(File.join(src, 'excluded_file.txt'), 'content')
          File.write(File.join(src, 'included_file.txt'), 'content')

          FileUtils.mkdir_p(dest)
        end

        it 'excludes specified paths from files_to_copy including 3 subfolder levels' do
          subject.transfer

          expect(File.exist?(File.join(dest, 'included_folder', 'file1.txt'))).to be true
          expect(File.exist?(File.join(dest, 'excluded_folder', 'file2.txt'))).to be false
          expect(File.exist?(File.join(dest, 'subfolder', 'included_subfolder', 'file3.txt'))).to be true
          expect(File.exist?(File.join(dest, 'subfolder', 'excluded_subfolder', 'file4.txt'))).to be false
          expect(File.exist?(File.join(dest, 'subfolder', 'another_subfolder', 'included_subsubfolder', 'file5.txt'))).to be true
          expect(File.exist?(File.join(dest, 'subfolder', 'another_subfolder', 'excluded_subsubfolder', 'file6.txt'))).to be false
          expect(File.exist?(File.join(dest, 'excluded_file.txt'))).to be false
          expect(File.exist?(File.join(dest, 'included_file.txt'))).to be true
        end

        context "with excluded paths for dotfiles and dotfolders inside normal folders" do
          let(:excluded_paths) do
            [
              File.join(src, 'normal_folder/.dotfile_in_folder'),
              File.join(src, 'normal_folder/.dotfolder_in_folder')
            ]
          end

          before do
            FileUtils.mkdir_p(File.join(src, 'normal_folder'))
            File.write(File.join(src, 'normal_folder/.dotfile_in_folder'), 'dotfile in folder content')
            FileUtils.mkdir_p(File.join(src, 'normal_folder/.dotfolder_in_folder'))
            File.write(File.join(src, 'normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt'), 'file in dotfolder content')
            File.write(File.join(src, 'normal_folder/regular_file_in_folder.txt'), 'regular file in folder content')
          end

          it 'excludes dotfiles and dotfolders inside normal folders from files_to_copy' do
            subject.transfer

            expect(File.exist?(File.join(dest, 'normal_folder/.dotfile_in_folder'))).to be false
            expect(File.exist?(File.join(dest, 'normal_folder/.dotfolder_in_folder'))).to be false
            expect(File.exist?(File.join(dest, 'normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt'))).to be false
            expect(File.exist?(File.join(dest, 'normal_folder/regular_file_in_folder.txt'))).to be true
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
    let(:excluded_paths) { [] }

    before do
      FileUtils.mkdir_p(src_folder)
      FileUtils.mkdir_p(dest_folder)
      File.write(src, 'source file content')
    end

    after { FileUtils.rm_rf(root) }

    context "when destination is a folder" do
      let(:dest) { dest_folder }

      it 'creates the destination file with the source file' do
        subject.transfer

        dest_file = File.join(dest, "src_file")
        expect(File.exist?(dest_file)).to be true
        expect(File.read(dest_file)).to eq('source file content')
      end
    end

    context "when destination is a file" do
      let(:dest) { File.join(dest_folder, "dest_file") }

      context "and the file exist" do
        before do
          File.write(dest, 'destination file content')
        end

        it 'replaces the destination file with the source file' do
          subject.transfer

          expect(File.exist?(dest)).to be true
          expect(File.read(dest)).to eq('source file content')
        end
      end

      context "and the file does not exist" do
        it 'creates the destination file with the source file' do
          subject.transfer

          expect(File.exist?(dest)).to be true
          expect(File.read(dest)).to eq('source file content')
        end
      end

    end
  end
end
