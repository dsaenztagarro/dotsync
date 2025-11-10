# frozen_string_literal: true

require "spec_helper"
require_relative "support/logger_helper"

RSpec.describe Dotsync::PushAction do
  include LoggerHelper

  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:mapping1) do
    Dotsync::Mapping.new(
      "src" => File.join(root, "src1"),
      "dest" => File.join(root, "dest1"),
      "force" => true,
      "ignore" => []
    )
  end
  let(:mapping2) do
    Dotsync::Mapping.new(
      "src" => File.join(root, "src2"),
      "dest" => File.join(root, "dest2"),
      "force" => false,
      "ignore" => []
    )
  end
  let(:mappings) { [mapping1, mapping2] }
  let(:config) do
    instance_double(
      "Dotsync::PushActionConfig",
      mappings: mappings
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:file_transfer1) { instance_double("Dotsync::FileTransfer") }
  let(:file_transfer2) { instance_double("Dotsync::FileTransfer") }
  let(:action) { Dotsync::PushAction.new(config, logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(logger).to receive(:log)
    allow(logger).to receive(:action)
    FileUtils.mkdir_p(root)
    FileUtils.touch(mapping1.src)
    FileUtils.touch(mapping1.dest)
    File.write(mapping2.src, "#{mapping2.src} content")
    File.write(mapping2.dest, "#{mapping2.dest} content")
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#execute" do
    let(:icon_force) { Dotsync::Icons.force }
    let(:icon_invalid) { Dotsync::Icons.invalid }
    let(:icon_diff_updated) { Dotsync::Icons.diff_updated }
    let(:color_diff_updated) { Dotsync::Colors.diff_modifications }

    before do
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[0]).and_return(file_transfer1)
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[1]).and_return(file_transfer2)
      allow(file_transfer1).to receive(:transfer)
      allow(file_transfer2).to receive(:transfer)
    end

    it "shows command log" do
      expect_show_options
      expect_show_mappings_legend
      expect_show_mappings([
        [icon_force, "/tmp/dotsync/src1", "/tmp/dotsync/dest1"],
        ["", "/tmp/dotsync/src2", "/tmp/dotsync/dest2"]
      ])
      expect_show_differences_legend
      expect_show_differences([
        { text: "#{icon_diff_updated}/tmp/dotsync/dest2", color: color_diff_updated }
      ])

      action.execute
    end

    context "without differences" do
      before do
        File.write(mapping2.dest, "#{mapping2.src} content")
      end

      it "shows no differences" do
        expect_show_no_differences

        action.execute
      end
    end

    context "without apply option" do
      it "doest not transfer mappings" do
        action.execute

        expect(file_transfer1).to_not have_received(:transfer)
        expect(file_transfer2).to_not have_received(:transfer)
      end
    end

    context "with apply option" do
      let(:subject) { action.execute(apply: true, yes: true) }

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
          expect_show_options(apply: true)
          expect_show_mappings_legend
          expect_show_mappings([
            [icon_force, "/tmp/dotsync/src1", "/tmp/dotsync/dest1"],
            [icon_invalid, "/tmp/dotsync/src2", "/tmp/dotsync/dest2"]
          ])

          expect(file_transfer1).to receive(:transfer)
          expect(file_transfer2).to_not receive(:transfer)

          subject
        end
      end
    end
  end
end
