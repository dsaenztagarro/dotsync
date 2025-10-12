require "spec_helper"

RSpec.describe Dotsync::PushAction do
  let(:src) { '/tmp/dotsync_src' }
  let(:dest) { '/tmp/dotsync_dest' }
  let(:remove_dest) { true }
  let(:excluded_paths) { [] }
  let(:config) do
    instance_double(
      'Dotsync::PushActionConfig',
      src: src,
      dest: dest,
      remove_dest: remove_dest,
      excluded_paths: excluded_paths
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:action) { Dotsync::PushAction.new(config, logger) }

  before do
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
    allow(logger).to receive(:info)
    allow(logger).to receive(:action)
  end

  after do
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(dest)
  end

  describe '#execute' do
    it 'pushes file to destination' do
      FileUtils.touch(File.join(src, 'testfile'))

      action.execute

      expect(File.exist?(File.join(dest, 'testfile'))).to be true
      expect(logger).to have_received(:action).with("Dotfiles pushed", icon: :copy)
    end

    context 'when source file exists in destination' do
      before do
        File.write(File.join(src, 'testfile'), 'source content')
        File.write(File.join(dest, 'testfile'), 'destination content')
      end

      it 'overwrites the file in the destination with the source version' do
        action.execute

        file_path = File.join(dest, 'testfile')
        expect(File.exist?(file_path)).to be true
        expect(File.read(file_path)).to eq('source content')
      end
    end

    context 'when a folder is pushed' do
      before do
        FileUtils.mkdir_p(File.join(src, 'folder/subfolder1'))
        File.write(File.join(src, 'folder/subfolder1', 'file1.txt'), 'source content')
      end

      it 'copies the folder and its contents to the destination' do
        action.execute

        folder_path = File.join(dest, 'folder/subfolder1')
        expect(Dir.exist?(folder_path)).to be true
        expect(File.read(File.join(folder_path, 'file1.txt'))).to eq('source content')
      end
    end

    context 'with excluded paths' do
      let(:excluded_paths) { ['excluded_folder', 'excluded_file.txt'] }

      before do
        FileUtils.mkdir_p(File.join(src, 'included_folder'))
        FileUtils.mkdir_p(File.join(src, 'excluded_folder'))
        File.write(File.join(src, 'included_folder', 'file1.txt'), 'content')
        File.write(File.join(src, 'excluded_folder', 'file2.txt'), 'content')
        File.write(File.join(src, 'excluded_file.txt'), 'content')
        File.write(File.join(src, 'included_file.txt'), 'content')

        FileUtils.mkdir_p(dest)
      end

      it 'excludes specified paths from files_to_copy' do
        action.execute

        expect(File.exist?(File.join(dest, 'included_folder', 'file1.txt'))).to be true
        expect(File.exist?(File.join(dest, 'excluded_folder', 'file2.txt'))).to be false
        expect(File.exist?(File.join(dest, 'excluded_file.txt'))).to be false
        expect(File.exist?(File.join(dest, 'included_file.txt'))).to be true
      end
    end
  end
end
