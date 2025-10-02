require "spec_helper"

RSpec.describe Dotsync::PullAction do
  let(:action) { Dotsync::PullAction.new(config, logger) }
  let(:config) { double('Dotsync::PullActionConfig',
    backups_root: backups_root,
    src: src,
    dest: dest
  ) }
  let(:backups_root) { '/tmp/dotsync_backups' }
  let(:src) { '/tmp/dotsync_src' }
  let(:dest) { '/tmp/dotsync_dest' }
  let(:logger) { Dotsync::Logger.new(File.open(File::NULL, 'w')) }

  before do
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
  end

  after do
    FileUtils.rm_rf(backups_root)
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(dest)
  end

  describe '#execute' do
    context 'when the configuration file exists' do
      it 'successfully completes the sync process' do
        FileUtils.touch(File.join(src, 'testfile'))
        action.execute
        expect(Dir.exist?(backups_root)).to be true
        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
        expect(File.exist?(File.join(dest, 'testfile'))).to be true
      end
    end

    context 'when the configuration file does not exist' do
      before do
        FileUtils.rm_f(config_path)
      end

      it 'logs an error and aborts the sync' do
        expect(action).to receive(:log).with(:error, "Configuration file not found at #{config_path}. Aborting sync.")
        action.execute
      end
    end

    context 'when there are conflicts in the destination' do
      it 'removes conflicting files and syncs new files' do
        FileUtils.touch(File.join(src, 'testfile'))
        FileUtils.touch(File.join(dest, 'testfile'))
        action.execute
        expect(File.exist?(File.join(dest, 'testfile'))).to be true
        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
      end
    end

    context 'when a backup is generated' do
      it 'creates a backup with the proper content' do
        FileUtils.touch(File.join(src, 'testfile'))
        action.execute
        backup_dir = Dir[File.join(backups_root, 'config-*')].first
        expect(backup_dir).not_to be_nil
        expect(File.exist?(File.join(backup_dir, 'testfile'))).to be true
      end
    end

    context 'when there are more than 10 backups' do
      it 'cleans up old backups and creates a new one' do
        12.times do |i|
          FileUtils.mkdir_p(File.join(backups_root, "config-#{i}"))
        end
        action.execute
        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(10)
      end
    end
  end
end
