require "spec_helper"

RSpec.describe Dotsync::PullAction do
  let(:mappings) do
    [
      { src: '/tmp/dotsync_src1', dest: '/tmp/dotsync_dest1', remove_dest: true, excluded_paths: [] },
      { src: '/tmp/dotsync_src2', dest: '/tmp/dotsync_dest2', remove_dest: false, excluded_paths: [] }
    ]
  end
  let(:src) { mappings.map { |mapping| mapping[:src] }.uniq }
  let(:dest) { mappings.map { |mapping| mapping[:dest] }.uniq }
  let(:remove_dest) { true }
  let(:backups_root) { '/tmp/dotsync_backups' }
  let(:excluded_paths) { [] }
  let(:config) do
    instance_double(
      'Dotsync::PullActionConfig',
      mappings: mappings,
      backups_root: backups_root
    )
  end
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:file_transfer) { instance_double("Dotsync::FileTransfer") }
  let(:action) { Dotsync::PullAction.new(config, logger) }

  before do
    FileUtils.mkdir_p(backups_root)
    src.each { |source| FileUtils.mkdir_p(File.dirname(source)) }
    src.each { |source| FileUtils.touch(source) unless File.directory?(source) }
    dest.each { |destination| FileUtils.mkdir_p(destination) }
    allow(logger).to receive(:info)
    allow(logger).to receive(:warning)
    allow(logger).to receive(:action)
  end

  after do
    FileUtils.rm_rf(backups_root)
    src.each { |source| FileUtils.rm_rf(source) }
    dest.each { |destination| FileUtils.rm_rf(destination) }
  end

  describe '#execute' do
    before do
      allow(Dotsync::FileTransfer).to receive(:new).and_return(file_transfer)
      allow(file_transfer).to receive(:transfer)
    end

    it 'transfers mappings of sources to corresponding destinations' do
      action.execute

      mappings.each do |mapping|
        expect(Dotsync::FileTransfer).to have_received(:new).with(mapping)
        expect(file_transfer).to have_received(:transfer).at_least(:once)
      end
    end
  end
end
