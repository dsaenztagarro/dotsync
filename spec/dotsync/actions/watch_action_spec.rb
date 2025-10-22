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
  let(:logger) { Dotsync::Logger.new }
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

      expect(logger).to receive(:info).with("Mappings:", icon: :watch).ordered.once
      expect(logger).to receive(:info).with("  src: #{src} -> dest: #{dest}", {icon: :copy}).ordered.once
      expect(logger).to receive(:action).with('Listening for changes...', icon: :listen).ordered
      expect(logger).to receive(:info).with('Press Ctrl+C to exit.').ordered

      expect { action.execute }.to raise_error(SystemExit)
    end

    it 'copies a file to the destination and logs the action when added' do
      testfile_src = File.join(src, "testfile")
      testfile_dest = File.join(dest, "testfile")
      sanitized_src = sanitize_path testfile_src
      sanitized_dest = sanitize_path testfile_dest

      allow(FileUtils).to receive(:cp)
      allow(FileUtils).to receive(:mkdir_p)

      Thread.new do
        sleep 0.1
        File.write(testfile_src, 'source content')
        sleep 0.25
        Process.kill('INT', Process.pid)
      end

      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(sanitized_dest)).ordered
      expect(FileUtils).to receive(:cp).with(sanitized_src, sanitized_dest).ordered

      expect(logger).to receive(:info).with('Copied file', icon: :copy)

      expect { action.execute }.to raise_error(SystemExit)
    end
  end
end
