require "spec_helper"

RSpec.describe Dotsync::PullAction do
  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:folder_src) { File.join(src, "folder_src") }
  let(:file1_src) { File.join(folder_src, "file1") }
  let(:file2_src) { File.join(src, "file2") }
  let(:dest) { File.join(root, "dest") }
  let(:folder_dest) { File.join(dest, "folder_dest") }
  let(:file1_dest) { File.join(folder_dest, "file1") }
  let(:file2_dest) { File.join(dest, "file2") }
  let(:files) { [file1_src, file2_src, file1_dest, file2_dest] }
  let(:mappings) do
    [
      { src: folder_src, dest: folder_dest, remove_dest: true, excluded_paths: [] },
      { src: file2_src, dest: file2_dest }
    ]
  end
  let(:backups_root) { File.join(root, "backups") }
  let(:config) do
    instance_double(
      'Dotsync::PullActionConfig',
      mappings: mappings,
      backups_root: backups_root
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:file_transfer1) { instance_double("Dotsync::FileTransfer") }
  let(:file_transfer2) { instance_double("Dotsync::FileTransfer") }
  let(:action) { Dotsync::PullAction.new(config, logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:warning)
    allow(logger).to receive(:action)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe '#execute' do
    before do
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[0]).and_return(file_transfer1)
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[1]).and_return(file_transfer2)
      allow(file_transfer1).to receive(:transfer)
      allow(file_transfer2).to receive(:transfer)
    end

    it 'transfers mappings of sources to corresponding destinations' do
      action.execute

      expect(file_transfer1).to have_received(:transfer)
      expect(file_transfer2).to have_received(:transfer)
    end

    context 'when no destination already exist' do
      it 'does not create a backup folder' do
        action.execute

        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        backup_dir = File.join(backups_root, timestamp)
        expect(Dir.exist?(backup_dir)).to eq(false)
      end
    end

    context 'when destination already exist' do
      before do
        require "timecop"
        Timecop.freeze(2025, 2, 1)
        FileUtils.mkdir_p(folder_src)
        FileUtils.mkdir_p(folder_dest)
        FileUtils.mkdir_p(backups_root)
        files.each { |file| File.write(file, "#{file} content") }
      end

      it 'creates a backup with the proper content' do
        action.execute

        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        backup_dir = File.join(backups_root, timestamp)
        expect(Dir.exist?(backup_dir)).to eq(true)
        expect(File.read(File.join(backup_dir, "folder_dest", "file1"))).to eq("#{file1_dest} content")
        expect(File.read(File.join(backup_dir, "file2"))).to eq("#{file2_dest} content")

        expect(logger).to have_received(:action).with("Backup created:", icon: :backup)
        expect(logger).to have_received(:info).with("  #{backup_dir}")
      end

      context 'when there are more than 10 backups' do
        before do
          1.upto(12) do |day|
            date = Date.new(2025, 1, day).strftime('%Y%m%d%H%M%S')
            FileUtils.mkdir_p(File.join(backups_root, date))
          end
        end

        it 'cleans up old backups and creates a new one' do
          action.execute

          expect(Dir[File.join(backups_root, '*')].size).to eq(10)
          expect(logger).to have_received(:info).with("Maximum of 10 backups retained")
          1.upto(2) do |day|
            expect(logger).to have_received(:info).with("Old backup deleted: #{File.join(backups_root, "2025010#{day}000000")}", icon: :delete)
          end
        end
      end
    end
  end
end
