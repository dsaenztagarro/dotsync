# frozen_string_literal: true

require "spec_helper"
require "timecop"
require "fileutils"
require "tmpdir"

RSpec.describe Dotsync::VersionChecker do
  let(:current_version) { "0.1.17" }
  let(:logger) { instance_double(Dotsync::Logger) }
  let(:cache_dir) { File.join(Dir.tmpdir, "dotsync_test_cache") }
  let(:cache_file) { File.join(cache_dir, "dotsync", "last_version_check") }

  subject(:checker) { described_class.new(current_version, logger: logger) }

  before do
    # Clean up cache directory
    FileUtils.rm_rf(cache_dir) if File.exist?(cache_dir)

    # Mock XDG cache home to use temp directory
    allow(checker).to receive(:xdg_cache_home).and_return(cache_dir)

    # Suppress debug logging in tests
    allow(logger).to receive(:log)
    allow(ENV).to receive(:[]).and_call_original
  end

  after do
    FileUtils.rm_rf(cache_dir) if File.exist?(cache_dir)
    Timecop.return
  end

  describe "#should_check?" do
    context "when DOTSYNC_NO_UPDATE_CHECK is set" do
      before do
        allow(ENV).to receive(:[]).with("DOTSYNC_NO_UPDATE_CHECK").and_return("1")
      end

      it "returns false" do
        expect(checker.should_check?).to be false
      end
    end

    context "when cache file does not exist" do
      it "returns true" do
        expect(checker.should_check?).to be true
      end
    end

    context "when cache file exists and is fresh (< 24 hours)" do
      before do
        FileUtils.mkdir_p(File.dirname(cache_file))
        File.write(cache_file, (Time.now - 3600).iso8601) # 1 hour ago
      end

      it "returns false" do
        expect(checker.should_check?).to be false
      end
    end

    context "when cache file exists and is stale (> 24 hours)" do
      before do
        FileUtils.mkdir_p(File.dirname(cache_file))
        File.write(cache_file, (Time.now - 86401).iso8601) # 24 hours + 1 second ago
      end

      it "returns true" do
        expect(checker.should_check?).to be true
      end
    end

    context "when cache file is corrupted" do
      before do
        FileUtils.mkdir_p(File.dirname(cache_file))
        File.write(cache_file, "invalid timestamp")
      end

      it "returns true and handles error gracefully" do
        expect(checker.should_check?).to be true
      end
    end
  end

  describe "#check_for_updates" do
    let(:api_response) { { "version" => "0.2.0" }.to_json }
    let(:http_response) { instance_double(Net::HTTPSuccess, body: api_response, is_a?: true) }

    before do
      allow(checker).to receive(:should_check?).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(http_response)
      allow($stderr).to receive(:puts)
    end

    context "when a newer version is available" do
      it "displays update message" do
        expect($stderr).to receive(:puts).with(/A new version of dotsync is available: 0.2.0/)
        checker.check_for_updates
      end

      it "updates the cache file" do
        checker.check_for_updates
        expect(File).to exist(cache_file)
      end
    end

    context "when current version is up to date" do
      let(:api_response) { { "version" => "0.1.17" }.to_json }

      it "does not display update message" do
        expect($stderr).not_to receive(:puts)
        checker.check_for_updates
      end

      it "still updates the cache file" do
        checker.check_for_updates
        expect(File).to exist(cache_file)
      end
    end

    context "when network request fails" do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(SocketError.new("Network error"))
      end

      it "does not raise an error" do
        expect { checker.check_for_updates }.not_to raise_error
      end

      it "does not display update message" do
        expect($stderr).not_to receive(:puts)
        checker.check_for_updates
      end
    end

    context "when network request times out" do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout.new)
      end

      it "does not raise an error" do
        expect { checker.check_for_updates }.not_to raise_error
      end
    end

    context "when API returns invalid JSON" do
      let(:http_response) { instance_double(Net::HTTPSuccess, body: "invalid json", is_a?: true) }

      it "does not raise an error" do
        expect { checker.check_for_updates }.not_to raise_error
      end
    end

    context "when should_check? returns false" do
      before do
        allow(checker).to receive(:should_check?).and_return(false)
      end

      it "does not make network request" do
        expect(Net::HTTP).not_to receive(:start)
        checker.check_for_updates
      end
    end
  end

  describe "#fetch_latest_version" do
    let(:api_response) { { "version" => "0.2.5" }.to_json }
    let(:http_response) { instance_double(Net::HTTPSuccess, body: api_response) }

    before do
      allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(http_response)
    end

    it "fetches version from RubyGems API" do
      expect(checker.send(:fetch_latest_version)).to eq("0.2.5")
    end

    context "when API returns non-success response" do
      before do
        allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      end

      it "returns nil" do
        expect(checker.send(:fetch_latest_version)).to be_nil
      end
    end

    context "when network error occurs" do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(SocketError.new("Network error"))
      end

      it "returns nil" do
        expect(checker.send(:fetch_latest_version)).to be_nil
      end
    end
  end

  describe "version comparison" do
    it "correctly identifies when current version is outdated" do
      expect(checker.send(:version_outdated?, "0.1.17", "0.2.0")).to be true
      expect(checker.send(:version_outdated?, "0.1.17", "0.1.18")).to be true
      expect(checker.send(:version_outdated?, "1.0.0", "2.0.0")).to be true
    end

    it "correctly identifies when current version is up to date" do
      expect(checker.send(:version_outdated?, "0.2.0", "0.2.0")).to be false
      expect(checker.send(:version_outdated?, "0.2.0", "0.1.17")).to be false
    end

    context "with invalid version strings" do
      it "returns false and handles error gracefully" do
        expect(checker.send(:version_outdated?, "invalid", "0.2.0")).to be false
      end
    end
  end

  describe "cache file management" do
    it "creates cache directory if it doesn't exist" do
      expect(File).not_to exist(File.dirname(cache_file))

      allow(checker).to receive(:should_check?).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(
        instance_double(Net::HTTPSuccess, body: { "version" => "0.2.0" }.to_json, is_a?: true)
      )
      allow($stderr).to receive(:puts)

      checker.check_for_updates

      expect(File).to exist(File.dirname(cache_file))
    end

    it "writes timestamp in ISO8601 format" do
      Timecop.freeze(Time.new(2025, 11, 10, 14, 30, 0, "-08:00")) do
        checker.send(:update_cache)
        content = File.read(cache_file)
        expect(content).to match(/2025-11-10T14:30:00-08:00/)
      end
    end

    it "reads timestamp correctly" do
      timestamp = Time.new(2025, 11, 10, 14, 30, 0, "-08:00")
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, timestamp.iso8601)

      expect(checker.send(:last_check_time)).to be_within(1).of(timestamp)
    end
  end

  describe "display format" do
    before do
      allow($stderr).to receive(:puts)
    end

    it "includes version information and upgrade command" do
      expect($stderr).to receive(:puts) do |msg|
        expect(msg).to include("0.2.0")
        expect(msg).to include("0.1.17")
        expect(msg).to include("gem update dotsync")
      end

      checker.send(:display_update_message, "0.2.0")
    end

    it "uses colored output" do
      expect($stderr).to receive(:puts) do |msg|
        expect(msg).to include("\e[38;5;226m") # Yellow color
        expect(msg).to include("\e[0m") # Reset color
      end

      checker.send(:display_update_message, "0.2.0")
    end
  end
end
