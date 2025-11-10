# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Runner do
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:config_path) { "/tmp/dotsync/test_config.toml" }
  let(:runner) { described_class.new(logger: logger, config_path: config_path) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(logger).to receive(:log)
    allow(logger).to receive(:action)
  end

  after do
    FileUtils.rm_rf("/tmp/dotsync")
  end

  describe "#initialize" do
    it "accepts custom logger" do
      runner = described_class.new(logger: logger)
      expect(runner.instance_variable_get(:@logger)).to eq(logger)
    end

    it "creates default logger when not provided" do
      runner = described_class.new
      expect(runner.instance_variable_get(:@logger)).to be_a(Dotsync::Logger)
    end

    it "accepts custom config_path" do
      runner = described_class.new(config_path: "/custom/path.toml")
      expect(runner.instance_variable_get(:@config_path)).to eq("/custom/path.toml")
    end
  end

  describe "#run" do
    context "with setup action" do
      before do
        allow(Dotsync).to receive(:config_path).and_return(config_path)
      end

      it "creates config file" do
        runner.run(:setup)

        expect(File.exist?(config_path)).to be(true)
      end

      it "creates parent directory if needed" do
        runner.run(:setup)

        expect(Dir.exist?(File.dirname(config_path))).to be(true)
      end

      it "writes example mappings as TOML" do
        runner.run(:setup)

        content = File.read(config_path)
        expect(content).to include("[icons]")
        expect(content).to include("[[pull.mappings]]")
        expect(content).to include("[[push.mappings]]")
        expect(content).to include("[[watch.mappings]]")
        expect(content).to include("$XDG_CONFIG_HOME")
      end

      it "logs success message" do
        expect(logger).to receive(:info).with("Configuration file created at #{config_path}")

        runner.run(:setup)
      end
    end

    context "with pull action" do
      let(:config) { instance_double("Dotsync::PullActionConfig") }
      let(:action) { instance_double("Dotsync::PullAction") }

      before do
        allow(Dotsync).to receive(:config_path).and_return(config_path)
        allow(Dotsync::PullActionConfig).to receive(:new).and_return(config)
        allow(config).to receive(:to_h).and_return({})
        allow(Dotsync::PullAction).to receive(:new).and_return(action)
        allow(action).to receive(:execute)
        allow(Dotsync::Icons).to receive(:load_custom_icons)
        allow(Dotsync::Colors).to receive(:load_custom_colors)
      end

      it "loads config and executes action" do
        expect(Dotsync::PullActionConfig).to receive(:new).with(Dotsync.config_path)
        expect(Dotsync::PullAction).to receive(:new).with(config, logger)
        expect(action).to receive(:execute).with({})

        runner.run(:pull)
      end

      it "loads custom icons from config" do
        custom_config = { "icons" => { "force" => "🔥" } }
        allow(config).to receive(:to_h).and_return(custom_config)

        expect(Dotsync::Icons).to receive(:load_custom_icons).with(custom_config)

        runner.run(:pull)
      end

      it "loads custom colors from config" do
        custom_config = { "colors" => { "diff_additions" => 32 } }
        allow(config).to receive(:to_h).and_return(custom_config)

        expect(Dotsync::Colors).to receive(:load_custom_colors).with(custom_config)

        runner.run(:pull)
      end

      it "passes options to action" do
        expect(action).to receive(:execute).with({ apply: true })

        runner.run(:pull, apply: true)
      end

      context "when ConfigError occurs" do
        before do
          allow(Dotsync::PullActionConfig).to receive(:new).and_raise(
            Dotsync::ConfigError, "Config file not found"
          )
        end

        it "handles error gracefully" do
          expect(logger).to receive(:error).with("[pull] config error:")
          expect(logger).to receive(:info).with("Config file not found")

          expect { runner.run(:pull) }.not_to raise_error
        end
      end
    end

    context "with push action" do
      let(:config) { instance_double("Dotsync::PushActionConfig") }
      let(:action) { instance_double("Dotsync::PushAction") }

      before do
        allow(Dotsync).to receive(:config_path).and_return(config_path)
        allow(Dotsync::PushActionConfig).to receive(:new).and_return(config)
        allow(config).to receive(:to_h).and_return({})
        allow(Dotsync::PushAction).to receive(:new).and_return(action)
        allow(action).to receive(:execute)
        allow(Dotsync::Icons).to receive(:load_custom_icons)
        allow(Dotsync::Colors).to receive(:load_custom_colors)
      end

      it "loads config and executes action" do
        expect(Dotsync::PushActionConfig).to receive(:new).with(Dotsync.config_path)
        expect(Dotsync::PushAction).to receive(:new).with(config, logger)
        expect(action).to receive(:execute).with({})

        runner.run(:push)
      end
    end

    context "with watch action" do
      let(:config) { instance_double("Dotsync::WatchActionConfig") }
      let(:action) { instance_double("Dotsync::WatchAction") }

      before do
        allow(Dotsync).to receive(:config_path).and_return(config_path)
        allow(Dotsync::WatchActionConfig).to receive(:new).and_return(config)
        allow(config).to receive(:to_h).and_return({})
        allow(Dotsync::WatchAction).to receive(:new).and_return(action)
        allow(action).to receive(:execute)
        allow(Dotsync::Icons).to receive(:load_custom_icons)
        allow(Dotsync::Colors).to receive(:load_custom_colors)
      end

      it "loads config and executes action" do
        expect(Dotsync::WatchActionConfig).to receive(:new).with(Dotsync.config_path)
        expect(Dotsync::WatchAction).to receive(:new).with(config, logger)
        expect(action).to receive(:execute).with({})

        runner.run(:watch)
      end
    end

    context "with unknown action" do
      it "handles NameError and displays helpful message" do
        expect(logger).to receive(:error).with("Unknown action 'invalid_action':")
        expect(logger).to receive(:info)

        runner.run(:invalid_action)
      end
    end

    context "when generic error occurs during action" do
      let(:config) { instance_double("Dotsync::PullActionConfig") }
      let(:action) { instance_double("Dotsync::PullAction") }

      before do
        allow(Dotsync).to receive(:config_path).and_return(config_path)
        allow(Dotsync::PullActionConfig).to receive(:new).and_return(config)
        allow(config).to receive(:to_h).and_return({})
        allow(Dotsync::PullAction).to receive(:new).and_return(action)
        allow(Dotsync::Icons).to receive(:load_custom_icons)
        allow(Dotsync::Colors).to receive(:load_custom_colors)
        allow(action).to receive(:execute).and_raise(RuntimeError, "Something went wrong")
      end

      it "logs error and re-raises" do
        expect(logger).to receive(:error).with("Error running 'pull':")
        expect(logger).to receive(:info).with("Something went wrong")

        expect { runner.run(:pull) }.to raise_error(RuntimeError, "Something went wrong")
      end
    end

    context "version checking" do
      let(:version_checker) { instance_double("Dotsync::VersionChecker") }
      let(:config) { instance_double("Dotsync::PullActionConfig") }
      let(:action) { instance_double("Dotsync::PullAction") }

      before do
        allow(Dotsync).to receive(:config_path).and_return(config_path)
        allow(Dotsync::PullActionConfig).to receive(:new).and_return(config)
        allow(config).to receive(:to_h).and_return({})
        allow(Dotsync::PullAction).to receive(:new).and_return(action)
        allow(action).to receive(:execute)
        allow(Dotsync::Icons).to receive(:load_custom_icons)
        allow(Dotsync::Colors).to receive(:load_custom_colors)
        allow(Dotsync::VersionChecker).to receive(:new).and_return(version_checker)
        allow(version_checker).to receive(:should_check?).and_return(false)
        allow(version_checker).to receive(:check_for_updates)
      end

      it "checks for updates when should_check? is true" do
        allow(version_checker).to receive(:should_check?).and_return(true)

        expect(version_checker).to receive(:check_for_updates)

        runner.run(:pull)
      end

      it "skips check when DOTSYNC_NO_UPDATE_CHECK is set" do
        ENV["DOTSYNC_NO_UPDATE_CHECK"] = "1"

        expect(Dotsync::VersionChecker).not_to receive(:new)

        runner.run(:pull)

        ENV.delete("DOTSYNC_NO_UPDATE_CHECK")
      end

      it "handles version check failures silently" do
        allow(version_checker).to receive(:should_check?).and_return(true)
        allow(version_checker).to receive(:check_for_updates).and_raise(StandardError, "Network error")

        expect { runner.run(:pull) }.not_to raise_error
      end

      it "logs debug message when DEBUG is set and version check fails" do
        ENV["DEBUG"] = "1"
        allow(version_checker).to receive(:should_check?).and_return(true)
        allow(version_checker).to receive(:check_for_updates).and_raise(StandardError, "Network error")

        expect(logger).to receive(:log).with("Debug: Version check failed - Network error")

        runner.run(:pull)

        ENV.delete("DEBUG")
      end
    end
  end

  describe "#camelize" do
    it "converts pull to Pull" do
      result = runner.send(:camelize, "pull")
      expect(result).to eq("Pull")
    end

    it "converts push to Push" do
      result = runner.send(:camelize, "push")
      expect(result).to eq("Push")
    end

    it "converts watch to Watch" do
      result = runner.send(:camelize, "watch")
      expect(result).to eq("Watch")
    end

    it "handles snake_case with underscores" do
      result = runner.send(:camelize, "pull_action")
      expect(result).to eq("PullAction")
    end
  end
end
