# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::HookRunner do
  let(:root) { File.join("/tmp", "dotsync_hook_runner_test") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:logger) { instance_double("Dotsync::Logger") }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(logger).to receive(:log)
    FileUtils.mkdir_p(src)
    FileUtils.mkdir_p(dest)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#execute" do
    context "with a single successful command" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["echo hello"]
        )
      end
      let(:changed_files) { [File.join(dest, "file1.txt")] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "executes the command and returns success" do
        results = runner.execute

        expect(results.size).to eq(1)
        expect(results.first[:success]).to be true
        expect(results.first[:stdout]).to include("hello")
      end

      it "logs success" do
        runner.execute

        expect(logger).to have_received(:info).with(/Hook succeeded/, icon: :hook)
      end
    end

    context "with multiple commands" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["echo first", "echo second"]
        )
      end
      let(:changed_files) { [File.join(dest, "file1.txt")] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "executes all commands sequentially" do
        results = runner.execute

        expect(results.size).to eq(2)
        expect(results[0][:stdout]).to include("first")
        expect(results[1][:stdout]).to include("second")
      end
    end

    context "with a failing command" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["false", "echo after_failure"]
        )
      end
      let(:changed_files) { [File.join(dest, "file1.txt")] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "logs error but continues with remaining hooks" do
        results = runner.execute

        expect(results.size).to eq(2)
        expect(results[0][:success]).to be false
        expect(results[1][:success]).to be true
        expect(logger).to have_received(:error).with(/Hook failed/)
      end
    end

    context "with template variable {files}" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["echo {files}"]
        )
      end
      let(:changed_files) { [File.join(dest, "file1.txt"), File.join(dest, "file2.txt")] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "expands {files} with shell-escaped paths" do
        results = runner.execute

        expect(results.first[:stdout]).to include("file1.txt")
        expect(results.first[:stdout]).to include("file2.txt")
      end
    end

    context "with files containing spaces" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["echo {files}"]
        )
      end
      let(:changed_files) { [File.join(dest, "my file.txt")] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "shell-escapes file paths with spaces" do
        results = runner.execute

        expect(results.first[:stdout]).to include("my")
        expect(results.first[:success]).to be true
      end
    end

    context "with files containing environment variables" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["echo {files}"]
        )
      end
      let(:changed_files) { ["$HOME/Scripts/setup.sh"] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "expands environment variables in file paths" do
        results = runner.execute

        expect(results.first[:stdout]).to include(ENV["HOME"])
        expect(results.first[:stdout]).to include("Scripts/setup.sh")
        expect(results.first[:success]).to be true
      end
    end

    context "with template variables {src} and {dest}" do
      let(:mapping) do
        Dotsync::Mapping.new(
          "src" => src,
          "dest" => dest,
          "hooks" => ["echo {src} {dest}"]
        )
      end
      let(:changed_files) { [File.join(dest, "file1.txt")] }
      let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

      it "expands {src} and {dest} to mapping paths" do
        results = runner.execute

        expect(results.first[:stdout]).to include(mapping.src)
        expect(results.first[:stdout]).to include(mapping.dest)
      end
    end
  end

  describe "#preview" do
    let(:mapping) do
      Dotsync::Mapping.new(
        "src" => src,
        "dest" => dest,
        "hooks" => ["codesign -s - {files}", "chmod 700 {files}"]
      )
    end
    let(:changed_files) { [File.join(dest, "script.sh")] }
    let(:runner) { described_class.new(mapping: mapping, changed_files: changed_files, logger: logger) }

    it "returns expanded commands without executing" do
      commands = runner.preview

      expect(commands.size).to eq(2)
      expect(commands[0]).to include("codesign")
      expect(commands[0]).to include("script.sh")
      expect(commands[1]).to include("chmod")
      expect(commands[1]).to include("script.sh")
    end

    it "does not execute any commands" do
      expect(Open3).not_to receive(:capture3)

      runner.preview
    end
  end
end
