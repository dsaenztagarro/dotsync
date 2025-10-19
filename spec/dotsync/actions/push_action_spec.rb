require "spec_helper"

RSpec.describe Dotsync::PushAction do
  let(:mappings) do
    [
      { src: '/tmp/dotsync_src1', dest: '/tmp/dotsync_dest1', force: true, ignore: [] },
      { src: '/tmp/dotsync_src2', dest: '/tmp/dotsync_dest2', force: false, ignore: [] }
    ]
  end
  let(:config) do
    instance_double(
      'Dotsync::PushActionConfig',
      mappings: mappings
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:file_transfer) { instance_double("Dotsync::FileTransfer") }
  let(:action) { Dotsync::PushAction.new(config, logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:action)
  end

  describe '#execute' do
    before do
      allow(Dotsync::FileTransfer).to receive(:new).and_return(file_transfer)
      allow(file_transfer).to receive(:transfer)
    end

    it 'shows config' do
      action.execute

      expect(logger).to have_received(:info).with("Mappings:", icon: :source_dest).ordered.once
      expect(logger).to have_received(:info).with("Source: /tmp/dotsync_src1 -> Destination: /tmp/dotsync_dest1", {icon: :copy}).ordered.once
      expect(logger).to have_received(:info).with("Remove destination: true", {icon: :delete}).ordered.once
      expect(logger).to have_received(:info).with("Source: /tmp/dotsync_src2 -> Destination: /tmp/dotsync_dest2", {icon: :copy}).ordered.once
      expect(logger).to have_received(:info).with("Remove destination: false", {icon: :delete}).ordered.once
    end

    it 'transfers mappings of sources to corresponding destinations' do
      action.execute

      mappings.each do |mapping|
        expect(Dotsync::FileTransfer).to have_received(:new).with(mapping)
      end
      expect(file_transfer).to have_received(:transfer).twice
    end
  end
end
