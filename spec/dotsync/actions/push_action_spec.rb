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
  let(:file_transfer) { instance_double("Dotsync::FileTransfer") }
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
    it 'transfers file to destination' do
      allow(Dotsync::FileTransfer).to receive(:new).with(config).and_return(file_transfer)
      allow(file_transfer).to receive(:transfer)

      FileUtils.touch(File.join(src, 'testfile'))

      action.execute

      expect(file_transfer).to have_received(:transfer)
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
  end
end
