# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::PullAction do
  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:file1_src) { File.join(mapping1.src, "file1") }
  let(:file1_dest) { File.join(mapping1.dest, "file1") }
  let(:file2_src) { File.join(src, "file2") }
  let(:file2_dest) { File.join(dest, "file2") }
  let(:files) { [file1_src, file2_src, file1_dest, file2_dest] }
  let(:mapping1) do
    Dotsync::Mapping.new(
      "src" => File.join(src, "folder_src"),
      "dest" => File.join(dest, "folder_dest"),
      "force" => true,
      "ignore" => []
    )
  end
  let(:mapping2) do
    Dotsync::Mapping.new(
      "src" => file2_src,
      "dest" => file2_dest
    )
  end
  let(:mappings) { [mapping1, mapping2] }
  let(:backups_root) { File.join(root, "backups") }
  let(:config) do
    instance_double(
      "Dotsync::PullActionConfig",
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
    allow(logger).to receive(:error)
    allow(logger).to receive(:log)
    allow(logger).to receive(:action)
    FileUtils.mkdir_p(mapping1.src)
    FileUtils.mkdir_p(mapping1.dest)
    File.write(mapping2.src, "#{mapping2.src} content")
    File.write(mapping2.dest, "#{mapping2.dest} content")
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#execute" do
    let(:color_modifications) { Dotsync::Colors.diff_modifications }
    let(:icon_force) { Dotsync::Icons.force }
    let(:icon_invalid) { Dotsync::Icons.invalid }

    before do
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[0]).and_return(file_transfer1)
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[1]).and_return(file_transfer2)
      allow(file_transfer1).to receive(:transfer)
      allow(file_transfer2).to receive(:transfer)
    end

    it "shows config" do
      action.execute

      expect(logger).to have_received(:info).with("Mappings:", icon: :config).ordered.once
      expect(logger).to have_received(:log).with("  /tmp/dotsync/src/folder_src → /tmp/dotsync/dest/folder_dest #{icon_force}").ordered.once
      expect(logger).to have_received(:log).with("  /tmp/dotsync/src/file2 → /tmp/dotsync/dest/file2").ordered.once
    end

    it "shows diff" do
      action.execute

      expect(logger).to have_received(:info).with("Diff:", icon: :diff).ordered.once
      expect(logger).to have_received(:log).with("  /tmp/dotsync/dest/file2", color: color_modifications).ordered.once
    end

    context "without diff" do
      before do
        FileUtils.rm(mapping2.src)
        FileUtils.rm(mapping2.dest)
      end

      it "shows diff" do
        action.execute

        expect(logger).to have_received(:info).with("Diff:", icon: :diff).ordered.once
        expect(logger).to have_received(:log).with("  No differences").ordered.once
      end
    end

    context "with apply option" do
      let(:subject) { action.execute(apply: true) }

      it "transfers mappings correctly" do
        subject

        expect(file_transfer1).to have_received(:transfer)
        expect(file_transfer2).to have_received(:transfer)
      end

      context "with invalid mapping" do
        before do
          FileUtils.rm(mapping2.src)
          FileUtils.rm(mapping2.dest)
        end

        it "transfers mappings correctly and logs skipped invalid mapping" do
          subject

          expect(logger).to have_received(:info).with("Mappings:", icon: :config).ordered.once
          expect(logger).to have_received(:log).with("  /tmp/dotsync/src/folder_src → /tmp/dotsync/dest/folder_dest #{icon_force}").ordered.once
          expect(logger).to have_received(:log).with("  /tmp/dotsync/src/file2 → /tmp/dotsync/dest/file2 #{icon_invalid}").ordered.once

          expect(file_transfer1).to have_received(:transfer)
          expect(file_transfer2).to_not have_received(:transfer)
        end
      end

      context "backup" do
        context "without valid mappings" do
          before do
            FileUtils.rm_rf(dest)
          end

          it "does not create a backup folder" do
            subject

            timestamp = Time.now.strftime("%Y%m%d%H%M%S")
            backup_dir = File.join(backups_root, timestamp)
            expect(Dir.exist?(backup_dir)).to eq(false)
          end
        end

        context "with valid mappings" do
          before do
            require "timecop"
            Timecop.freeze(2025, 2, 1)
            FileUtils.mkdir_p(mapping1.src)
            FileUtils.mkdir_p(mapping1.dest)
            FileUtils.mkdir_p(backups_root)
            files.each { |file| File.write(file, "#{file} content") }
          end

          it "creates a backup with the proper content" do
            subject

            timestamp = Time.now.strftime("%Y%m%d%H%M%S")
            backup_dir = File.join(backups_root, timestamp)
            expect(Dir.exist?(backup_dir)).to eq(true)
            expect(File.read(File.join(backup_dir, "folder_dest", "file1"))).to eq("#{file1_dest} content")
            expect(File.read(File.join(backup_dir, "file2"))).to eq("#{file2_dest} content")

            expect(logger).to have_received(:action).with("Backup created:")
            expect(logger).to have_received(:log).with("  #{backup_dir}")
          end

          context "when there are more than 10 backups" do
            before do
              1.upto(12) do |day|
                date = Date.new(2025, 1, day).strftime("%Y%m%d%H%M%S")
                FileUtils.mkdir_p(File.join(backups_root, date))
              end
            end

            it "cleans up old backups and creates a new one" do
              subject

              expect(Dir[File.join(backups_root, "*")].size).to eq(10)
              expect(logger).to have_received(:action).with("Oldest backup deleted:").ordered.once
              1.upto(2) do |day|
                backup_path = File.join(backups_root, "2025010#{day}000000")
                expect(logger).to have_received(:log).with("  #{backup_path}")
              end
            end
          end
        end
      end
    end
  end
end
