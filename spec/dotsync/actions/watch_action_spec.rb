require 'spec_helper'

RSpec.describe Dotsync::WatchAction do
  include Dotsync::PathUtils

  let(:src) { '/tmp/src' }
  let(:dest) { '/tmp/dest' }
  let(:watched_paths) { ['/tmp/src'] }
  let(:config) do
    instance_double(
      'Dotsync::WatchActionConfig',
      src: src,
      dest: dest,
      watched_paths: watched_paths
    )
  end
  let(:logger) { instance_double('Dotsync::Logger', action: nil, info: nil) }
  let(:action) { described_class.new(config, logger) }

  before do
    watched_paths.each { |path| FileUtils.mkdir_p(path) }
    FileUtils.mkdir_p(dest)
  end

  describe '#execute' do
    it 'logs the watched paths and destination' do
      allow_any_instance_of(Listen::Listener).to receive(:start)
      Thread.new { sleep 0.1; Process.kill('INT', Process.pid) }

      expect(logger).to receive(:info).with('Watched paths:', icon: :watch).ordered
      expect(logger).to receive(:info).with('  /tmp/src').ordered
      expect(logger).to receive(:info).with('Destination:', icon: :dest).ordered
      expect(logger).to receive(:info).with('  /tmp/dest').ordered
      expect(logger).to receive(:action).with('Listening for changes...', icon: :listen).ordered
      expect(logger).to receive(:info).with('Press Ctrl+C to exit.').ordered
      expect { action.execute }.to raise_error(SystemExit)
    end

    it 'copies a file to the destination and logs the action when added' do
      dest_path = '/tmp/dest/testfile'
      file_path = sanitize_path '/tmp/src/testfile'
      sanitized_dest = sanitize_path dest_path

      allow(FileUtils).to receive(:cp)
      Thread.new do
        sleep 0.1
        File.write(file_path, 'source content')
        sleep 0.25
        Process.kill('INT', Process.pid)
      end

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(dest_path)).ordered
      expect(FileUtils).to receive(:cp).with(file_path, sanitized_dest).ordered
      expect(logger).to receive(:info).with('Copied file', icon: :copy).ordered
      expect(logger).to receive(:info).with("  ~/testfile → #{sanitized_dest}").ordered

      expect { action.execute }.to raise_error(SystemExit)
    end
  end
end
