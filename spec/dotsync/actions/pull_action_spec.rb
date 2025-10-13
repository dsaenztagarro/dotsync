require "spec_helper"

RSpec.describe Dotsync::PullAction do
  let(:src) { '/tmp/dotsync_src' }
  let(:dest) { '/tmp/dotsync_dest' }
  let(:backups_root) { '/tmp/dotsync_backups' }
  let(:excluded_paths) { [] }
  let(:config) do
    instance_double(
      'Dotsync::PullActionConfig',
      src: src,
      dest: dest,
      backups_root: backups_root,
      excluded_paths: excluded_paths
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:action) { Dotsync::PullAction.new(config, logger) }

  before do
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warning)
    allow(logger).to receive(:action)
  end

  after do
    FileUtils.rm_rf(backups_root)
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(dest)
  end

  describe '#execute' do
    it 'pulls file in destination' do
      FileUtils.touch(File.join(src, 'testfile'))

      action.execute

      expect(Dir.exist?(backups_root)).to be true
      expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
      expect(File.exist?(File.join(dest, 'testfile'))).to be true
      expect(logger).to have_received(:action).with("Dotfiles pulled", icon: :copy)
    end

    context 'when pulled file exist in destination' do
      before do
        File.write(File.join(src, 'testfile'), 'source content')
        File.write(File.join(dest, 'testfile'), 'destination content')
      end

      it 'replaces the file with the source version' do
        action.execute

        file_path = File.join(dest, 'testfile')
        expect(File.exist?(file_path)).to be true
        expect(File.read(file_path)).to eq('source content')
        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
        expect(logger).to have_received(:warning).with("Removed from destination", icon: :delete)
        expect(logger).to have_received(:info).with("  #{file_path}")
      end
    end

    context 'when pulled folder exist in destination' do
      before do
        FileUtils.mkdir_p(File.join(src, 'folder/subfolder1'))
        FileUtils.mkdir_p(File.join(dest, 'folder/subfolder2'))
        File.write(File.join(src, 'folder/subfolder1', 'file1.txt'), 'source content')
        File.write(File.join(dest, 'folder/subfolder2', 'file2.txt'), 'destination content')
      end

      it 'replaces the folder with the source version' do
        action.execute

        folder_path = File.join(dest, 'folder/subfolder1')
        removed_path = File.join(dest, 'folder')
        expect(Dir.exist?(folder_path)).to be true
        expect(File.read(File.join(folder_path, 'file1.txt'))).to eq('source content')
        expect(logger).to have_received(:warning).with("Removed from destination", icon: :delete)
        expect(logger).to have_received(:info).with("  #{removed_path}")
      end
    end

    context 'when a backup is generated' do
      before do
        require 'timecop'
        FileUtils.touch(File.join(src, 'testfile'))
        Timecop.freeze(Time.now + 1) do
          FileUtils.touch(File.join(dest, 'testfile'))
        end
      end

      it 'creates a backup with the proper content' do
        action.execute

        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        backup_dir = File.join(backups_root, "config-#{timestamp}")
        expect(Dir.exist?(backup_dir)).to be true
        expect(Dir.entries(backup_dir)).to include('testfile')
        expect(File.mtime(File.join(backup_dir, 'testfile'))).to be < File.mtime(File.join(dest, 'testfile'))
        expect(logger).to have_received(:action).with("Backup created:", icon: :backup)
        expect(logger).to have_received(:info).with("  #{backup_dir}")
      end
    end

    context 'when there are more than 10 backups' do
      before do
        12.times do |i|
          date = Date.new(2025, 1, i + 1).strftime('%Y%m%d')
          FileUtils.mkdir_p(File.join(backups_root, "config-#{date}"))
        end
      end

      it 'cleans up old backups and creates a new one' do
        action.execute

        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(10)
        expect(logger).to have_received(:info).with("Maximum of 10 backups retained")
        expect(logger).to have_received(:info).with("Old backup deleted: #{File.join(backups_root, "config-20250103")}", icon: :delete)
        expect(logger).to have_received(:info).with("Old backup deleted: #{File.join(backups_root, "config-20250102")}", icon: :delete)
        expect(logger).to have_received(:info).with("Old backup deleted: #{File.join(backups_root, "config-20250101")}", icon: :delete)
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
        action.execute

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
          action.execute

          expect(File.exist?(File.join(dest, 'normal_folder/.dotfile_in_folder'))).to be false
          expect(File.exist?(File.join(dest, 'normal_folder/.dotfolder_in_folder'))).to be false
          expect(File.exist?(File.join(dest, 'normal_folder/.dotfolder_in_folder/file_in_dotfolder.txt'))).to be false
          expect(File.exist?(File.join(dest, 'normal_folder/regular_file_in_folder.txt'))).to be true
        end
      end
    end
  end
end
