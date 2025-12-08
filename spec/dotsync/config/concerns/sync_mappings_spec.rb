# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::SyncMappings do
  let(:test_class) do
    Class.new do
      include Dotsync::SyncMappings

      def initialize(config)
        @config = config
      end
    end
  end

  let(:root) { File.join("/tmp", "dotsync_sync_test") }
  let(:local_path) { File.join(root, "local") }
  let(:remote_path) { File.join(root, "remote") }

  before do
    FileUtils.mkdir_p(local_path)
    FileUtils.mkdir_p(remote_path)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe "#sync_mappings_for_push" do
    context "with sync mappings" do
      let(:config) do
        {
          "sync" => [
            { "local" => local_path, "remote" => remote_path, "force" => true, "ignore" => ["cache"] }
          ]
        }
      end

      it "converts sync mappings to push format (local -> remote)" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_push

        expect(mappings.size).to eq(1)
        # Mapping sanitizes paths, translating /tmp to /private/tmp on macOS
        expect(mappings.first.src).to end_with("dotsync_sync_test/local")
        expect(mappings.first.dest).to end_with("dotsync_sync_test/remote")
        expect(mappings.first.force?).to eq(true)
      end
    end

    context "without sync section" do
      let(:config) { {} }

      it "returns empty array" do
        instance = test_class.new(config)
        expect(instance.sync_mappings_for_push).to eq([])
      end
    end
  end

  describe "#sync_mappings_for_pull" do
    context "with sync mappings" do
      let(:config) do
        {
          "sync" => [
            { "local" => local_path, "remote" => remote_path, "force" => true, "only" => ["config"] }
          ]
        }
      end

      it "converts sync mappings to pull format (remote -> local)" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_pull

        expect(mappings.size).to eq(1)
        # Mapping sanitizes paths, translating /tmp to /private/tmp on macOS
        expect(mappings.first.src).to end_with("dotsync_sync_test/remote")
        expect(mappings.first.dest).to end_with("dotsync_sync_test/local")
        expect(mappings.first.force?).to eq(true)
      end
    end
  end

  describe "#validate_sync_mappings!" do
    context "with valid sync mappings" do
      let(:config) do
        {
          "sync" => [
            { "local" => local_path, "remote" => remote_path }
          ]
        }
      end

      it "does not raise an error" do
        instance = test_class.new(config)
        expect { instance.send(:validate_sync_mappings!) }.not_to raise_error
      end
    end

    context "with invalid sync mappings missing local" do
      let(:config) do
        {
          "sync" => [
            { "remote" => remote_path }
          ]
        }
      end

      it "raises a ConfigError" do
        instance = test_class.new(config)
        expect { instance.send(:validate_sync_mappings!) }.to raise_error(Dotsync::ConfigError)
      end
    end

    context "with invalid sync mappings missing remote" do
      let(:config) do
        {
          "sync" => [
            { "local" => local_path }
          ]
        }
      end

      it "raises a ConfigError" do
        instance = test_class.new(config)
        expect { instance.send(:validate_sync_mappings!) }.to raise_error(Dotsync::ConfigError)
      end
    end
  end
end
