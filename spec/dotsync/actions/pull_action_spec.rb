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
  let(:logger) { instance_double("Dotsync::Logger") }

  before do
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
    allow(logger).to receive(:info)
    allow(logger).to receive(:success)
    allow(logger).to receive(:error)
  end

  after do
    FileUtils.rm_rf(backups_root)
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(dest)
  end

  describe '#execute' do
    it 'successfully completes the sync process' do
      FileUtils.touch(File.join(src, 'testfile'))

      action.execute

      expect(Dir.exist?(backups_root)).to be true
      expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
      expect(File.exist?(File.join(dest, 'testfile'))).to be true
      expect(logger).to have_received(:success).with("Dotfile sync complete")
    end

    context 'when pulled file exist in destination' do
      before do
        FileUtils.touch(File.join(src, 'testfile'))
        FileUtils.touch(File.join(dest, 'testfile'))
      end

      it 'removes conflicting files and syncs new files' do
        action.execute
        expect(File.exist?(File.join(dest, 'testfile'))).to be true
        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
        expect(logger).to have_received(:info).with("Conflicting files detected and resolved.")
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
        expect(logger).to have_received(:info).with("Backup created successfully at #{backup_dir}.")
      end
    end

    context 'when there are more than 10 backups' do
      before do
        12.times do |i|
          FileUtils.mkdir_p(File.join(backups_root, "config-#{i}"))
        end
      end

      it 'cleans up old backups and creates a new one' do
        action.execute
        expect(Dir[File.join(backups_root, 'config-*')].size).to eq(10)
        expect(logger).to have_received(:info).with("Old backups cleaned up. Maximum of 10 backups retained.")
      end
    end
  end
end

