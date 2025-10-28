# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::PushAction do
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
    FileUtils.touch(mapping2.src)
    FileUtils.touch(mapping2.dest)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#execute" do
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
      expect(logger).to have_received(:log).with("  /tmp/dotsync/src1 → /tmp/dotsync/dest1 #{icon_force}").ordered.once
      expect(logger).to have_received(:log).with("  /tmp/dotsync/src2 → /tmp/dotsync/dest2").ordered.once
    end

    it "transfers mappings correctly" do
      action.execute

      expect(file_transfer1).to have_received(:transfer)
      expect(file_transfer2).to have_received(:transfer)
    end

    context "with invalid mapping" do
      before do
        FileUtils.rm(mapping2.src)
        FileUtils.rm(mapping2.dest)
      end

      it "transfers mappings correctly and logs skipped invalid mapping" do
        action.execute

        expect(logger).to have_received(:info).with("Mappings:", icon: :config).ordered.once
        expect(logger).to have_received(:log).with("  /tmp/dotsync/src1 → /tmp/dotsync/dest1 #{icon_force}").ordered.once
        expect(logger).to have_received(:log).with("  /tmp/dotsync/src2 → /tmp/dotsync/dest2 #{icon_invalid}").ordered.once

        expect(file_transfer1).to have_received(:transfer)
        expect(file_transfer2).to_not have_received(:transfer)
      end
    end
  end
end
