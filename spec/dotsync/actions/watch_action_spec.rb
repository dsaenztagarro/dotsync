require 'spec_helper'

RSpec.describe Dotsync::WatchAction do
  include Dotsync::PathUtils

  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:mappings) do
    [
      Dotsync::MappingEntry.new("src" => src, "dest" => dest)
    ]
  end
  let(:config) do
    instance_double(
      'Dotsync::WatchActionConfig',
      mappings: mappings
    )
  end
  let(:logger) { instance_double('Dotsync::Logger', action: nil, info: nil) }
  let(:action) { described_class.new(config, logger) }

  before do
    [src, dest].each { |path| FileUtils.mkdir_p(path) }
    FileUtils.mkdir_p(dest)
    allow(logger).to receive(:info)
    allow(logger).to receive(:action)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe '#execute' do
    it 'shows config' do
      allow_any_instance_of(Listen::Listener).to receive(:start)
      Thread.new { sleep 0.1; Process.kill('INT', Process.pid) }

      # icon_delete = Dotsync::Logger::ICONS[:delete]

      # expect(logger).to have_received(:info).with("Mappings:", icon: :watch).ordered.once
      expect(logger).to receive(:info).with("  src: #{src} -> dest: #{dest}", {icon: :copy}).ordered.once

      expect(logger).to receive(:action).with('Listening for changes...', icon: :listen).ordered
      expect(logger).to receive(:info).with('Press Ctrl+C to exit.').ordered

      expect { action.execute }.to raise_error(SystemExit)
    end

    it 'copies a file to the destination and logs the action when added' do
      original_dest = '/tmp/dotsync/dest/testfile'
      file_path = sanitize_path '/tmp/dotsync/src/testfile'
      dest_path = sanitize_path original_dest
      sanitized_dest = sanitize_path dest_path

      allow(FileUtils).to receive(:cp)
      Thread.new do
        sleep 0.1
        File.write(file_path, 'source content')
        sleep 3.25
        Process.kill('INT', Process.pid)
      end

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(dest_path)).ordered
      expect(FileUtils).to receive(:cp).with(file_path, dest_path) # .ordered

      expect(logger).to receive(:info).with('Copied file', icon: :copy).ordered

      expect { action.execute }.to raise_error(SystemExit)
    end
  end
end
