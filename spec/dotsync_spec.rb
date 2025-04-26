require 'spec_helper'
require 'fileutils'

RSpec.describe Dotsync::Sync do
  let(:sync) { Dotsync::Sync.new }
  let(:backup_root) { '/tmp/dotsync_backups' }
  let(:src) { '/tmp/dotsync_src' }
  let(:dest) { '/tmp/dotsync_dest' }
  let(:config_path) { '/tmp/dotsync_config.yml' }

  before do
    allow(sync).to receive(:backup_root).and_return(backup_root)
    allow(sync).to receive(:src).and_return(src)
    allow(sync).to receive(:dest).and_return(dest)
    stub_const('Dotsync::Sync::CONFIG_PATH', config_path)
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
    FileUtils.touch(config_path)
  end

  after do
    FileUtils.rm_rf(backup_root)
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(dest)
    FileUtils.rm_f(config_path)
  end

  describe '#timestamp' do
    it 'returns a timestamp string' do
      expect(sync.timestamp).to match(/\d{14}/)
    end
  end

  describe '#create_backup' do
    it 'creates a backup of the destination' do
      sync.create_backup
      expect(Dir.exist?(backup_root)).to be true
      expect(Dir[File.join(backup_root, 'config-*')].size).to eq(1)
    end
  end

  describe '#cleanup_old_backups' do
    it 'removes old backups if there are more than 10' do
      12.times do |i|
        FileUtils.mkdir_p(File.join(backup_root, "config-#{i}"))
      end
      sync.cleanup_old_backups
      expect(Dir[File.join(backup_root, 'config-*')].size).to eq(10)
    end
  end

  describe '#remove_conflicts' do
    it 'removes conflicting files from the destination' do
      FileUtils.touch(File.join(src, 'testfile'))
      FileUtils.touch(File.join(dest, 'testfile'))
      sync.remove_conflicts
      expect(File.exist?(File.join(dest, 'testfile'))).to be false
    end
  end

  describe '#sync_dotfiles' do
    it 'copies files from source to destination' do
      FileUtils.touch(File.join(src, 'testfile'))
      sync.sync_dotfiles
      expect(File.exist?(File.join(dest, 'testfile'))).to be true
    end
  end

  describe '#run!' do
    context 'when the configuration file exists' do
      it 'runs the sync process' do
        expect(sync).to receive(:create_backup)
        expect(sync).to receive(:remove_conflicts)
        expect(sync).to receive(:sync_dotfiles)
        sync.run!
      end
    end

    context 'when the configuration file does not exist' do
      before do
        FileUtils.rm_f(config_path)
      end

      it 'logs an error and aborts the sync' do
        expect(sync).to receive(:log).with(:error, "Configuration file not found at #{config_path}. Aborting sync.")
        sync.run!
      end
    end
  end
end
