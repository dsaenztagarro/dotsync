# frozen_string_literal: true

require "spec_helper"
require_relative "support/logger_helper"

RSpec.describe Dotsync::PullAction do
  include LoggerHelper

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
  let(:manifests_xdg_data_home) { File.join(root, "data") }
  let(:config) do
    instance_double(
      "Dotsync::PullActionConfig",
      mappings: mappings,
      backups_root: backups_root,
      manifests_xdg_data_home: manifests_xdg_data_home
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
    File.write(File.join(mapping1.src, "file1"), "src content")
    File.write(File.join(mapping1.dest, "file1"), "dest content")
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
    let(:icon_diff_updated) { Dotsync::Icons.diff_updated }
    let(:color_diff_updated) { Dotsync::Colors.diff_modifications }

    before do
      allow(Dotsync::FileTransfer).to receive(:new).and_call_original
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[0]).and_return(file_transfer1)
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[1]).and_return(file_transfer2)
      allow(file_transfer1).to receive(:transfer)
      allow(file_transfer2).to receive(:transfer)
    end


    it "shows command log" do
      expect_show_options
      expect_show_mappings_legend
      expect_show_mappings([
        [icon_force, "/tmp/dotsync/src/folder_src", "/tmp/dotsync/dest/folder_dest"],
        ["", "/tmp/dotsync/src/file2", "/tmp/dotsync/dest/file2"]
      ])
      expect_show_differences_legend
      expect_show_differences([
        { text: "#{icon_diff_updated}/tmp/dotsync/dest/file2", color: color_diff_updated },
        { text: "#{icon_diff_updated}/tmp/dotsync/dest/folder_dest/file1", color: color_diff_updated }
      ])

      action.execute
    end

    context "without differences" do
      before do
        File.write(File.join(mapping1.dest, "file1"), "src content")
        File.write(mapping2.dest, "#{mapping2.src} content")
      end

      it "shows no differences" do
        expect_show_no_differences

        action.execute
      end
    end

    context "with apply option" do
      let(:subject) { action.execute(apply: true, yes: true) }

      it "transfers mappings correctly" do
        subject

        expect(file_transfer1).to have_received(:transfer)
        expect(file_transfer2).to have_received(:transfer)
      end

      context "without differences" do
        before do
          File.write(File.join(mapping1.dest, "file1"), "src content")
          File.write(mapping2.dest, "#{mapping2.src} content")
        end

        it "skips transfer, orphan cleanup, and hooks" do
          subject

          expect(file_transfer1).not_to have_received(:transfer)
          expect(file_transfer2).not_to have_received(:transfer)
        end

        it "still shows mappings pulled message" do
          expect(logger).to receive(:action).with("Mappings pulled", icon: :done)

          subject
        end
      end

      context "with user confirmation" do
        context "when user accepts" do
          before do
            allow($stdin).to receive(:gets).and_return("y\n")
          end

          it "transfers mappings after confirmation" do
            action.execute(apply: true)

            expect(file_transfer1).to have_received(:transfer)
            expect(file_transfer2).to have_received(:transfer)
          end

          it "displays confirmation prompt" do
            expect(logger).to receive(:info).with("About to modify 2 file(s).", icon: :warning)

            action.execute(apply: true)
          end
        end

        context "when user declines" do
          before do
            allow($stdin).to receive(:gets).and_return("n\n")
          end

          it "does not transfer mappings" do
            action.execute(apply: true)

            expect(file_transfer1).not_to have_received(:transfer)
            expect(file_transfer2).not_to have_received(:transfer)
          end
        end

        context "when user provides empty response" do
          before do
            allow($stdin).to receive(:gets).and_return("\n")
          end

          it "does not transfer mappings" do
            action.execute(apply: true)

            expect(file_transfer1).not_to have_received(:transfer)
            expect(file_transfer2).not_to have_received(:transfer)
          end
        end

        context "when user provides uppercase Y" do
          before do
            allow($stdin).to receive(:gets).and_return("Y\n")
          end

          it "transfers mappings" do
            action.execute(apply: true)

            expect(file_transfer1).to have_received(:transfer)
            expect(file_transfer2).to have_received(:transfer)
          end
        end
      end

      context "with invalid mapping" do
        before do
          FileUtils.rm(mapping2.src)
          FileUtils.rm(mapping2.dest)
        end

        it "transfers mappings correctly and logs skipped invalid mapping" do
          expect_show_options(apply: true)
          expect_show_mappings_legend
          expect_show_mappings([
            [icon_force, "/tmp/dotsync/src/folder_src", "/tmp/dotsync/dest/folder_dest"],
            [icon_invalid, "/tmp/dotsync/src/file2", "/tmp/dotsync/dest/file2"]
          ])

          expect(file_transfer1).to receive(:transfer)
          expect(file_transfer2).to_not receive(:transfer)

          subject
        end
      end

      context "with hooks" do
        let(:mapping_with_hooks) do
          Dotsync::Mapping.new(
            "src" => file2_src,
            "dest" => file2_dest,
            "hooks" => ["echo hook_ran"]
          )
        end
        let(:mappings) { [mapping1, mapping_with_hooks] }

        before do
          allow(Dotsync::FileTransfer).to receive(:new).with(mappings[1]).and_return(file_transfer2)
        end

        it "executes hooks after transfer when files changed" do
          expect_any_instance_of(Dotsync::HookRunner).to receive(:execute).and_return([])

          action.execute(apply: true, yes: true)
        end

        context "when no files changed" do
          before do
            File.write(mapping_with_hooks.dest, "#{mapping_with_hooks.src} content")
          end

          it "does not execute hooks" do
            expect(Dotsync::HookRunner).not_to receive(:new)

            action.execute(apply: true, yes: true)
          end

          context "with force_hooks option" do
            it "executes hooks on all dest files" do
              expect_any_instance_of(Dotsync::HookRunner).to receive(:execute).and_return([])

              action.execute(apply: true, yes: true, force_hooks: true)
            end

            it "shows hooks preview in dry-run mode" do
              expect_any_instance_of(Dotsync::HookRunner).to receive(:preview).and_return(["echo hook_ran"])

              action.execute(force_hooks: true)
            end
          end
        end
      end

      context "with hooks and no differences" do
        let(:mapping_with_hooks) do
          Dotsync::Mapping.new(
            "src" => file2_src,
            "dest" => file2_dest,
            "hooks" => ["echo hook_ran"]
          )
        end
        let(:mappings) { [mapping1, mapping_with_hooks] }

        before do
          File.write(File.join(mapping1.dest, "file1"), "src content")
          File.write(mapping_with_hooks.dest, "#{mapping_with_hooks.src} content")
        end

        context "with force_hooks option" do
          it "executes hooks even without differences" do
            expect_any_instance_of(Dotsync::HookRunner).to receive(:execute).and_return([])

            action.execute(apply: true, yes: true, force_hooks: true)
          end
        end
      end

      context "hooks in dry-run mode" do
        let(:mapping_with_hooks) do
          Dotsync::Mapping.new(
            "src" => file2_src,
            "dest" => file2_dest,
            "hooks" => ["echo hook_ran"]
          )
        end
        let(:mappings) { [mapping1, mapping_with_hooks] }

        it "does not execute hooks without --apply" do
          expect_any_instance_of(Dotsync::HookRunner).not_to receive(:execute)

          action.execute
        end
      end

      context "backup" do
        context "without differences" do
          before do
            File.write(File.join(mapping1.dest, "file1"), "src content")
            File.write(mapping2.src, "#{mapping2.src} content")
            File.write(mapping2.dest, "#{mapping2.src} content")
          end

          it "does not create a backup" do
            subject

            expect(logger).to_not have_received(:action).with("Backup created:")
          end
        end

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

          context "when directory contains socket files" do
            let(:socket_path) { File.join(mapping1.dest, "daemon.sock") }

            before do
              require "socket"
              UNIXServer.new(socket_path)
            end

            after do
              File.delete(socket_path) if File.exist?(socket_path)
            end

            it "skips socket files during backup" do
              subject

              timestamp = Time.now.strftime("%Y%m%d%H%M%S")
              backup_dir = File.join(backups_root, timestamp)
              expect(Dir.exist?(backup_dir)).to eq(true)
              expect(File.exist?(File.join(backup_dir, "folder_dest", "daemon.sock"))).to eq(false)
              expect(File.read(File.join(backup_dir, "folder_dest", "file1"))).to eq("#{file1_dest} content")
            end
          end

          context "when backup directory has pre-existing symlinks" do
            it "overwrites the existing symlinks without crashing" do
              timestamp = Time.now.strftime("%Y%m%d%H%M%S")
              backup_dir = File.join(backups_root, timestamp)

              # Simulate a partial backup from a previous failed run
              FileUtils.mkdir_p(File.join(backup_dir, "folder_dest"))
              FileUtils.ln_s("old_target", File.join(backup_dir, "folder_dest", "file1"))

              # Create a symlink in the source to back up
              symlink_src = File.join(mapping1.dest, "link1")
              FileUtils.ln_s("some_target", symlink_src)

              subject

              expect(Dir.exist?(backup_dir)).to eq(true)
              backed_up_link = File.join(backup_dir, "folder_dest", "link1")
              expect(File.symlink?(backed_up_link)).to eq(true)
              expect(File.readlink(backed_up_link)).to eq("some_target")
            end
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

        context "with only filter" do
          let(:filtered_src) { File.join(src, "filtered_src") }
          let(:filtered_dest) { File.join(dest, "filtered_dest") }
          let(:mapping1) do
            Dotsync::Mapping.new(
              "src" => filtered_src,
              "dest" => filtered_dest,
              "only" => ["settings.json", "commands"],
              "force" => true
            )
          end
          let(:mappings) { [mapping1] }

          before do
            require "timecop"
            Timecop.freeze(2025, 2, 1)
            FileUtils.mkdir_p(filtered_src)
            FileUtils.mkdir_p(filtered_dest)
            FileUtils.mkdir_p(backups_root)

            # Create files matching the only filter
            File.write(File.join(filtered_src, "settings.json"), "src settings")
            File.write(File.join(filtered_dest, "settings.json"), "dest settings")
            FileUtils.mkdir_p(File.join(filtered_src, "commands"))
            FileUtils.mkdir_p(File.join(filtered_dest, "commands"))
            File.write(File.join(filtered_src, "commands", "cmd1"), "src cmd1")
            File.write(File.join(filtered_dest, "commands", "cmd1"), "dest cmd1")

            # Create files NOT matching the only filter (should be excluded from backup)
            FileUtils.mkdir_p(File.join(filtered_dest, "plugins", "marketplace", ".git", "objects"))
            File.write(File.join(filtered_dest, "plugins", "marketplace", ".git", "objects", "abc123"), "git object")
            File.write(File.join(filtered_dest, "workspace.json"), "workspace data")
          end

          it "only backs up files matching the only filter" do
            subject

            timestamp = Time.now.strftime("%Y%m%d%H%M%S")
            backup_dir = File.join(backups_root, timestamp)
            expect(Dir.exist?(backup_dir)).to eq(true)
            expect(File.read(File.join(backup_dir, "filtered_dest", "settings.json"))).to eq("dest settings")
            expect(File.read(File.join(backup_dir, "filtered_dest", "commands", "cmd1"))).to eq("dest cmd1")
            expect(File.exist?(File.join(backup_dir, "filtered_dest", "plugins"))).to eq(false)
            expect(File.exist?(File.join(backup_dir, "filtered_dest", "workspace.json"))).to eq(false)
          end
        end

        context "with ignore filter" do
          let(:ignored_src) { File.join(src, "ignored_src") }
          let(:ignored_dest) { File.join(dest, "ignored_dest") }
          let(:mapping1) do
            Dotsync::Mapping.new(
              "src" => ignored_src,
              "dest" => ignored_dest,
              "ignore" => ["lazy-lock.json"],
              "force" => true
            )
          end
          let(:mappings) { [mapping1] }

          before do
            require "timecop"
            Timecop.freeze(2025, 2, 1)
            FileUtils.mkdir_p(ignored_src)
            FileUtils.mkdir_p(ignored_dest)
            FileUtils.mkdir_p(backups_root)

            File.write(File.join(ignored_src, "init.lua"), "src init")
            File.write(File.join(ignored_dest, "init.lua"), "dest init")
            File.write(File.join(ignored_dest, "lazy-lock.json"), "lock data")
          end

          it "excludes ignored files from backup" do
            subject

            timestamp = Time.now.strftime("%Y%m%d%H%M%S")
            backup_dir = File.join(backups_root, timestamp)
            expect(Dir.exist?(backup_dir)).to eq(true)
            expect(File.read(File.join(backup_dir, "ignored_dest", "init.lua"))).to eq("dest init")
            expect(File.exist?(File.join(backup_dir, "ignored_dest", "lazy-lock.json"))).to eq(false)
          end
        end

        context "with only filter and permission-restricted files outside filter" do
          let(:restricted_src) { File.join(src, "restricted_src") }
          let(:restricted_dest) { File.join(dest, "restricted_dest") }
          let(:mapping1) do
            Dotsync::Mapping.new(
              "src" => restricted_src,
              "dest" => restricted_dest,
              "only" => ["settings.json"]
            )
          end
          let(:mappings) { [mapping1] }
          let(:restricted_file) { File.join(restricted_dest, "plugins", ".git", "objects", "abc123") }

          before do
            require "timecop"
            Timecop.freeze(2025, 2, 1)
            FileUtils.mkdir_p(restricted_src)
            FileUtils.mkdir_p(restricted_dest)
            FileUtils.mkdir_p(backups_root)

            File.write(File.join(restricted_src, "settings.json"), "src settings")
            File.write(File.join(restricted_dest, "settings.json"), "dest settings")

            # Create permission-restricted file outside the only filter
            FileUtils.mkdir_p(File.dirname(restricted_file))
            File.write(restricted_file, "restricted content")
            File.chmod(0o000, restricted_file)
          end

          after do
            File.chmod(0o644, restricted_file) if File.exist?(restricted_file)
          end

          it "does not crash and only backs up filtered files" do
            expect { subject }.not_to raise_error

            timestamp = Time.now.strftime("%Y%m%d%H%M%S")
            backup_dir = File.join(backups_root, timestamp)
            expect(File.read(File.join(backup_dir, "restricted_dest", "settings.json"))).to eq("dest settings")
            expect(File.exist?(File.join(backup_dir, "restricted_dest", "plugins"))).to eq(false)
          end
        end
      end

      context "orphan cleanup" do
        let(:bin_src) { File.join(root, "bin_src") }
        let(:bin_dest) { File.join(root, "bin_dest") }
        let(:mapping_with_inclusions) do
          Dotsync::Mapping.new(
            "src" => bin_src,
            "dest" => bin_dest,
            "only" => ["grafanactl", "elasticctl"],
            "sync_type" => "xdg_bin"
          )
        end
        let(:mappings) { [mapping_with_inclusions] }
        let(:manifest_path) { File.join(manifests_xdg_data_home, "dotsync/manifests/xdg_bin.json") }

        before do
          ENV["XDG_BIN_HOME"] = bin_dest
          ENV["XDG_BIN_HOME_MIRROR"] = bin_src
          FileUtils.mkdir_p(bin_src)
          FileUtils.mkdir_p(bin_dest)
          # Create files in both src and dest
          File.write(File.join(bin_src, "grafanactl"), "new content")
          File.write(File.join(bin_src, "elasticctl"), "new content")
          File.write(File.join(bin_dest, "grafanactl"), "old content")
          File.write(File.join(bin_dest, "elasticctl"), "old content")
          # Create orphan in dest (was in old manifest, no longer in src)
          File.write(File.join(bin_dest, "setup-grafana"), "orphan content")

          # Write old manifest with the orphan file
          FileUtils.mkdir_p(File.dirname(manifest_path))
          File.write(manifest_path, '{"files": ["elasticctl", "grafanactl", "setup-grafana"]}')

          allow(Dotsync::FileTransfer).to receive(:new).with(mapping_with_inclusions).and_return(
            instance_double("Dotsync::FileTransfer", transfer: nil)
          )
        end

        after do
          ENV.delete("XDG_BIN_HOME")
          ENV.delete("XDG_BIN_HOME_MIRROR")
        end

        it "removes orphan files after transfer" do
          action.execute(apply: true, yes: true)

          expect(File.exist?(File.join(bin_dest, "setup-grafana"))).to be false
        end

        it "updates the manifest after cleanup" do
          action.execute(apply: true, yes: true)

          data = JSON.parse(File.read(manifest_path))
          expect(data["files"]).to contain_exactly("elasticctl", "grafanactl")
        end

        it "preserves non-orphan files" do
          action.execute(apply: true, yes: true)

          expect(File.exist?(File.join(bin_dest, "grafanactl"))).to be true
          expect(File.exist?(File.join(bin_dest, "elasticctl"))).to be true
        end

        context "when no previous manifest exists" do
          before do
            FileUtils.rm(manifest_path)
          end

          it "writes a new manifest without removing any files" do
            action.execute(apply: true, yes: true)

            expect(File.exist?(File.join(bin_dest, "setup-grafana"))).to be true
            data = JSON.parse(File.read(manifest_path))
            expect(data["files"]).to contain_exactly("elasticctl", "grafanactl")
          end
        end

        context "with force mapping" do
          let(:mapping_with_inclusions) do
            Dotsync::Mapping.new(
              "src" => bin_src,
              "dest" => bin_dest,
              "only" => ["grafanactl", "elasticctl"],
              "force" => true,
              "sync_type" => "xdg_bin"
            )
          end

          it "skips orphan cleanup for force mappings" do
            action.execute(apply: true, yes: true)

            expect(File.exist?(File.join(bin_dest, "setup-grafana"))).to be true
          end
        end
      end

      context "error handling during transfer" do
        context "when PermissionError occurs" do
          before do
            allow(file_transfer1).to receive(:transfer).and_raise(
              Dotsync::PermissionError, "Permission denied for /tmp/dotsync/dest/folder_dest"
            )
          end

          it "logs error and helpful message" do
            expect(logger).to receive(:error).with("Permission denied: Permission denied for /tmp/dotsync/dest/folder_dest")
            expect(logger).to receive(:info).with("Try: chmod +w <path> or check file permissions")

            subject
          end

          it "continues with other mappings" do
            expect(file_transfer2).to receive(:transfer)

            subject
          end
        end

        context "when DiskFullError occurs" do
          before do
            allow(file_transfer1).to receive(:transfer).and_raise(
              Dotsync::DiskFullError, "No space left on device"
            )
          end

          it "logs error and helpful message" do
            expect(logger).to receive(:error).with("Disk full: No space left on device")
            expect(logger).to receive(:info).with("Free up disk space and try again")

            subject
          end
        end

        context "when SymlinkError occurs" do
          before do
            allow(file_transfer1).to receive(:transfer).and_raise(
              Dotsync::SymlinkError, "Broken symlink detected"
            )
          end

          it "logs error and helpful message" do
            expect(logger).to receive(:error).with("Symlink error: Broken symlink detected")
            expect(logger).to receive(:info).with("Check that symlink target exists and is accessible")

            subject
          end
        end

        context "when TypeConflictError occurs" do
          before do
            allow(file_transfer1).to receive(:transfer).and_raise(
              Dotsync::TypeConflictError, "Cannot overwrite directory with file"
            )
          end

          it "logs error and helpful message" do
            expect(logger).to receive(:error).with("Type conflict: Cannot overwrite directory with file")
            expect(logger).to receive(:info).with("Cannot overwrite directory with file or vice versa")

            subject
          end
        end

        context "when generic FileTransferError occurs" do
          before do
            allow(file_transfer1).to receive(:transfer).and_raise(
              Dotsync::FileTransferError, "Unknown transfer error"
            )
          end

          it "logs error message" do
            expect(logger).to receive(:error).with("File transfer failed: Unknown transfer error")

            subject
          end
        end
      end
    end
  end
end
