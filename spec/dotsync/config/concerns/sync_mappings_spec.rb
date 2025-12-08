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

  describe "XDG shorthand mappings" do
    before do
      ENV["XDG_CONFIG_HOME"] = File.join(root, "config")
      ENV["XDG_CONFIG_HOME_MIRROR"] = File.join(root, "config_mirror")
      ENV["XDG_DATA_HOME"] = File.join(root, "data")
      ENV["XDG_DATA_HOME_MIRROR"] = File.join(root, "data_mirror")
      ENV["HOME_MIRROR"] = File.join(root, "home_mirror")
      FileUtils.mkdir_p(ENV["XDG_CONFIG_HOME"])
      FileUtils.mkdir_p(ENV["XDG_CONFIG_HOME_MIRROR"])
      FileUtils.mkdir_p(File.join(ENV["XDG_CONFIG_HOME"], "nvim"))
      FileUtils.mkdir_p(File.join(ENV["XDG_CONFIG_HOME_MIRROR"], "nvim"))
    end

    after do
      ENV.delete("XDG_CONFIG_HOME")
      ENV.delete("XDG_CONFIG_HOME_MIRROR")
      ENV.delete("XDG_DATA_HOME")
      ENV.delete("XDG_DATA_HOME_MIRROR")
      ENV.delete("HOME_MIRROR")
    end

    describe "#sync_mappings_for_push with xdg_config shorthand" do
      let(:config) do
        {
          "sync" => {
            "xdg_config" => [
              { "path" => "nvim", "force" => true, "ignore" => ["lazy-lock.json"] }
            ]
          }
        }
      end

      it "expands xdg_config shorthand to full paths" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_push

        expect(mappings.size).to eq(1)
        expect(mappings.first.src).to end_with("config/nvim")
        expect(mappings.first.dest).to end_with("config_mirror/nvim")
        expect(mappings.first.force?).to eq(true)
      end
    end

    describe "#sync_mappings_for_pull with xdg_config shorthand" do
      let(:config) do
        {
          "sync" => {
            "xdg_config" => [
              { "path" => "nvim", "force" => true }
            ]
          }
        }
      end

      it "expands xdg_config shorthand to full paths (reversed for pull)" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_pull

        expect(mappings.size).to eq(1)
        expect(mappings.first.src).to end_with("config_mirror/nvim")
        expect(mappings.first.dest).to end_with("config/nvim")
      end
    end

    describe "#sync_mappings_for_push with xdg_data shorthand" do
      before do
        FileUtils.mkdir_p(File.join(ENV["XDG_DATA_HOME"], "git"))
        FileUtils.mkdir_p(File.join(ENV["XDG_DATA_HOME_MIRROR"], "git"))
      end

      let(:config) do
        {
          "sync" => {
            "xdg_data" => [
              { "path" => "git", "force" => true }
            ]
          }
        }
      end

      it "expands xdg_data shorthand to full paths" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_push

        expect(mappings.size).to eq(1)
        expect(mappings.first.src).to end_with("data/git")
        expect(mappings.first.dest).to end_with("data_mirror/git")
      end
    end

    describe "#sync_mappings_for_push with home shorthand" do
      before do
        FileUtils.mkdir_p(ENV["HOME_MIRROR"])
        FileUtils.touch(File.join(ENV["HOME"], ".zshenv"))
        FileUtils.touch(File.join(ENV["HOME_MIRROR"], ".zshenv"))
      end

      let(:config) do
        {
          "sync" => {
            "home" => [
              { "path" => ".zshenv" }
            ]
          }
        }
      end

      it "expands home shorthand to full paths" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_push

        expect(mappings.size).to eq(1)
        expect(mappings.first.original_src).to eq("$HOME/.zshenv")
        expect(mappings.first.original_dest).to eq("$HOME_MIRROR/.zshenv")
      end
    end

    describe "#sync_mappings_for_push with multiple XDG shorthands" do
      before do
        FileUtils.mkdir_p(File.join(ENV["XDG_DATA_HOME"], "git"))
        FileUtils.mkdir_p(File.join(ENV["XDG_DATA_HOME_MIRROR"], "git"))
      end

      let(:config) do
        {
          "sync" => {
            "xdg_config" => [
              { "path" => "nvim", "force" => true }
            ],
            "xdg_data" => [
              { "path" => "git" }
            ]
          }
        }
      end

      it "handles multiple XDG shorthand types" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_push

        expect(mappings.size).to eq(2)
      end
    end

    describe "#sync_mappings_for_push without path (entire XDG directory)" do
      let(:config) do
        {
          "sync" => {
            "xdg_config" => [
              { "force" => true }
            ]
          }
        }
      end

      it "uses the entire XDG directory when path is not specified" do
        instance = test_class.new(config)
        mappings = instance.sync_mappings_for_push

        expect(mappings.size).to eq(1)
        expect(mappings.first.original_src).to eq("$XDG_CONFIG_HOME")
        expect(mappings.first.original_dest).to eq("$XDG_CONFIG_HOME_MIRROR")
      end
    end

    describe "#validate_sync_mappings! with XDG shorthands" do
      context "with valid XDG shorthand mappings" do
        let(:config) do
          {
            "sync" => {
              "xdg_config" => [
                { "path" => "nvim" }
              ]
            }
          }
        end

        it "does not raise an error" do
          instance = test_class.new(config)
          expect { instance.send(:validate_sync_mappings!) }.not_to raise_error
        end
      end

      context "with invalid XDG shorthand mapping (not a hash)" do
        let(:config) do
          {
            "sync" => {
              "xdg_config" => ["invalid"]
            }
          }
        end

        it "raises a ConfigError" do
          instance = test_class.new(config)
          expect { instance.send(:validate_sync_mappings!) }.to raise_error(
            Dotsync::ConfigError,
            /Configuration error in sync.xdg_config mapping #1/
          )
        end
      end
    end
  end
end
