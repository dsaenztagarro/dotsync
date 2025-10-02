require 'spec_helper'

RSpec.describe Dotsync::WatchAction do
  let(:config) { instance_double('Dotsync::WatchActionConfig') }
  let(:logger) { instance_double('Dotsync::Logger', log: nil, info: nil, error: nil) }
  let(:action) { described_class.new(config, logger) }

  before do
    allow(config).to receive(:watched_paths).and_return(['/tmp/src'])
    allow(config).to receive(:output_directory).and_return('/tmp/dest')
  end

  describe '#execute' do
    it 'logs the watched paths and output directory' do
      expect(logger).to receive(:info).with('Watched paths:', icon: :watch)
      expect(logger).to receive(:info).with('  /tmp/src')
      expect(logger).to receive(:info).with('Output directory:', icon: :output)
      expect(logger).to receive(:info).with('  /tmp/dest')

      allow_any_instance_of(Listen::Listener).to receive(:start)
      Thread.new { sleep 0.5; Process.kill('INT', Process.pid) }
      expect { action.execute }.to raise_error(SystemExit)
    end

    it 'starts listeners and handles termination signals gracefully' do
      allow(logger).to receive(:info).with('Listening for changes. Press Ctrl+C to exit.')
      listener_mock = double('Listener', start: true)

      allow(Listen).to receive(:to).and_return(listener_mock)
      expect(listener_mock).to receive(:start).at_least(:once)

      Thread.new { sleep 0.5; Process.kill('INT', Process.pid) }
      expect { action.execute }.to raise_error(SystemExit)
    end
  end

  describe '#copy_file' do
    it 'copies a file to the output directory and logs the action' do
      file_path = '/tmp/src/testfile'
      dest_path = '/tmp/dest/testfile'

      allow(FileUtils).to receive(:mkdir_p)
      allow(FileUtils).to receive(:cp)

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(dest_path))
      expect(FileUtils).to receive(:cp).with(file_path, dest_path)
      expect(logger).to receive(:log).with(:event, 'Copied file', icon: :copy)
      expect(logger).to receive(:info).with("  ~/testfile → /tmp/dest/testfile")

      action.send(:copy_file, file_path)
    end
  end
end

