require "spec_helper"

RSpec.describe Dotsync::PullAction do
  let(:src) { '/tmp/dotsync_src' }
  let(:dest) { '/tmp/dotsync_dest' }
  let(:remove_dest) { true }
  let(:backups_root) { '/tmp/dotsync_backups' }
  let(:excluded_paths) { [] }
  let(:config) do
    instance_double(
      'Dotsync::PullActionConfig',
      src: src,
      dest: dest,
      remove_dest: remove_dest,
      excluded_paths: excluded_paths,
      backups_root: backups_root
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:file_transfer) { instance_double("Dotsync::FileTransfer") }
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
    it 'transfers file to destination' do
      allow(Dotsync::FileTransfer).to receive(:new).with(config).and_return(file_transfer)
      allow(file_transfer).to receive(:transfer)

      FileUtils.touch(File.join(src, 'testfile'))

      action.execute

      expect(Dir.exist?(backups_root)).to be true
      expect(Dir[File.join(backups_root, 'config-*')].size).to eq(1)
      expect(file_transfer).to have_received(:transfer)
      expect(logger).to have_received(:action).with("Dotfiles pulled", icon: :copy)
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
  end
end
