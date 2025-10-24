require "spec_helper"

RSpec.describe Dotsync::PushAction do
  let(:mappings) do
    [
      Dotsync::MappingEntry.new(
        "src" => "/tmp/dotsync_src1",
        "dest" => "/tmp/dotsync_dest1",
        "force" => true,
        "ignore" => []
      ),
      Dotsync::MappingEntry.new(
        "src" => "/tmp/dotsync_src2",
        "dest" => "/tmp/dotsync_dest2",
        "force" => false,
        "ignore" => []
      )
    ]
  end
  let(:config) do
    instance_double(
      'Dotsync::PushActionConfig',
      mappings: mappings
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:file_transfer1) { instance_double("Dotsync::FileTransfer") }
  let(:file_transfer2) { instance_double("Dotsync::FileTransfer") }
  let(:action) { Dotsync::PushAction.new(config, logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:action)
  end

  describe '#execute' do
    before do
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[0]).and_return(file_transfer1)
      allow(Dotsync::FileTransfer).to receive(:new).with(mappings[1]).and_return(file_transfer2)
      allow(file_transfer1).to receive(:transfer)
      allow(file_transfer2).to receive(:transfer)
    end

    it 'shows config' do
      action.execute

      icon_force = Dotsync::Logger::ICONS[:clean]

      expect(logger).to have_received(:info).with("Mappings:", icon: :config).ordered.once
      expect(logger).to have_received(:info).with("  /tmp/dotsync_src1 → /tmp/dotsync_dest1 #{icon_force}").ordered.once
      expect(logger).to have_received(:info).with("  /tmp/dotsync_src2 → /tmp/dotsync_dest2").ordered.once
    end

    it "transfers mappings correctly" do
      action.execute

      expect(file_transfer1).to have_received(:transfer)
      expect(file_transfer2).to have_received(:transfer)
    end
  end
end
