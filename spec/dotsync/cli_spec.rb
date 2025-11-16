# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "CLI executable (exe/dotsync)" do
  let(:exe_path) { File.expand_path("../../exe/dotsync", __dir__) }
  let(:lib_path) { File.expand_path("../../lib", __dir__) }

  # Helper method to run the CLI and capture output
  def run_cli(*args)
    env = { "DOTSYNC_NO_UPDATE_CHECK" => "1" }
    cmd = ["ruby", "-I", lib_path, exe_path] + args
    stdout, stderr, status = Open3.capture3(env, *cmd)
    {
      stdout: stdout,
      stderr: stderr,
      status: status,
      output: stdout + stderr
    }
  end

  describe "error handling" do
    context "with invalid options" do
      it "shows clean error message for invalid short option" do
        result = run_cli("push", "-z")

        expect(result[:output]).to include("Invalid option: -z")
        expect(result[:output]).to include("See 'dotsync --help' for available options")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "shows clean error message for invalid long option" do
        result = run_cli("push", "--invalid-option")

        expect(result[:output]).to include("Invalid option: --invalid-option")
        expect(result[:output]).to include("See 'dotsync --help' for available options")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "shows clean error message for malformed option" do
        result = run_cli("push", "--apply", "-yes")

        expect(result[:output]).to include("Invalid option: -es")
        expect(result[:output]).to include("See 'dotsync --help' for available options")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "does not show Ruby backtrace by default" do
        result = run_cli("push", "--invalid")

        expect(result[:output]).not_to include("exe/dotsync:")
        expect(result[:output]).not_to include("OptionParser::")
        expect(result[:output]).not_to include("from /")
        expect(result[:status].exitstatus).to eq(1)
      end
    end

    context "with --trace flag" do
      it "shows full backtrace for invalid options when --trace is before option parsing" do
        result = run_cli("--trace", "push", "--invalid")

        expect(result[:output]).to include("Invalid option: --invalid")
        expect(result[:output]).to include("Full backtrace:")
        expect(result[:output]).to include("exe/dotsync:")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "does not show backtrace when --trace comes after invalid option" do
        result = run_cli("push", "--invalid", "--trace")

        # Invalid option is caught before --trace is parsed
        expect(result[:output]).to include("Invalid option: --invalid")
        expect(result[:output]).not_to include("Full backtrace:")
        expect(result[:status].exitstatus).to eq(1)
      end
    end

    context "with unknown commands" do
      it "shows clean error for unknown command" do
        result = run_cli("invalidcommand")

        expect(result[:output]).to include("Unknown command: 'invalidcommand'")
        expect(result[:output]).to include("See 'dotsync --help' for available commands")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "shows clean error for typo in command" do
        result = run_cli("pussh")

        expect(result[:output]).to include("Unknown command: 'pussh'")
        expect(result[:output]).to include("See 'dotsync --help' for available commands")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "does not show Ruby backtrace for unknown commands" do
        result = run_cli("foobar")

        expect(result[:output]).not_to include("exe/dotsync:")
        expect(result[:output]).not_to include("from /")
        expect(result[:status].exitstatus).to eq(1)
      end
    end

    context "with no command" do
      it "shows help banner" do
        result = run_cli

        expect(result[:output]).to include("dotsync")
        expect(result[:output]).to include("Usage: dotsync [command] [options]")
        expect(result[:output]).to include("Commands:")
        expect(result[:output]).to include("push")
        expect(result[:output]).to include("pull")
        expect(result[:status].exitstatus).to eq(1)
      end

      it "does not show error message when no command provided" do
        result = run_cli

        expect(result[:output]).not_to include("Unknown command")
        expect(result[:output]).not_to include("Invalid option")
      end
    end
  end

  describe "--help flag" do
    it "displays help information" do
      result = run_cli("--help")

      expect(result[:output]).to include("dotsync")
      expect(result[:output]).to include("Usage: dotsync [command] [options]")
      expect(result[:output]).to include("Commands:")
      expect(result[:output]).to include("Examples:")
      expect(result[:output]).to include("Options:")
      expect(result[:status].exitstatus).to eq(0)
    end

    it "includes --trace in help options" do
      result = run_cli("--help")

      expect(result[:output]).to include("--trace")
      expect(result[:output]).to include("Show full error backtraces (for debugging)")
    end

    it "includes --trace in help examples" do
      result = run_cli("--help")

      expect(result[:output]).to include("dotsync push --trace")
      expect(result[:output]).to include("Show full error backtraces")
    end

    it "shows all commands" do
      result = run_cli("--help")

      expect(result[:output]).to include("push")
      expect(result[:output]).to include("pull")
      expect(result[:output]).to include("watch")
      expect(result[:output]).to include("setup")
      expect(result[:output]).to include("status")
      expect(result[:output]).to include("diff")
    end
  end

  describe "-h flag" do
    it "displays help information (short form)" do
      result = run_cli("-h")

      expect(result[:output]).to include("dotsync")
      expect(result[:output]).to include("Usage: dotsync [command] [options]")
      expect(result[:status].exitstatus).to eq(0)
    end
  end

  describe "--version flag" do
    it "displays version number" do
      result = run_cli("--version")

      expect(result[:output]).to match(/dotsync \d+\.\d+\.\d+/)
      expect(result[:status].exitstatus).to eq(0)
    end

    it "only shows version, nothing else" do
      result = run_cli("--version")

      lines = result[:output].strip.split("\n")
      expect(lines.length).to eq(1)
    end
  end

  describe "logger initialization" do
    it "initializes logger before option parsing" do
      # Test that logger is available by triggering an error
      result = run_cli("--invalid")

      # Should use logger.error, not raw exception
      expect(result[:output]).to include("Invalid option:")
      expect(result[:output]).not_to include("OptionParser::InvalidOption")
    end

    it "uses logger for unknown command errors" do
      result = run_cli("badcmd")

      # Should use logger.error
      expect(result[:output]).to include("Unknown command: 'badcmd'")
      # Should not be a raw puts message
      expect(result[:output]).not_to match(/^dotsync: no such command/)
    end
  end

  describe "valid commands" do
    context "setup command" do
      let(:test_config_path) { "/tmp/dotsync_test_cli_#{Time.now.to_i}.toml" }

      after do
        File.delete(test_config_path) if File.exist?(test_config_path)
      end

      it "creates config file successfully" do
        result = run_cli("setup", "--config", test_config_path)

        expect(result[:output]).to include("Configuration file created at")
        expect(result[:status].exitstatus).to eq(0)
        expect(File.exist?(test_config_path)).to be(true)
      end

      it "creates valid TOML config" do
        result = run_cli("setup", "--config", test_config_path)

        expect(result[:status].exitstatus).to eq(0)

        content = File.read(test_config_path)
        expect(content).to include("[icons]")
        expect(content).to include("[[pull.mappings]]")
        expect(content).to include("[[push.mappings]]")
      end
    end

    context "init command (alias for setup)" do
      let(:test_config_path) { "/tmp/dotsync_test_cli_init_#{Time.now.to_i}.toml" }

      after do
        File.delete(test_config_path) if File.exist?(test_config_path)
      end

      it "works as alias for setup" do
        result = run_cli("init", "--config", test_config_path)

        expect(result[:output]).to include("Configuration file created at")
        expect(result[:status].exitstatus).to eq(0)
        expect(File.exist?(test_config_path)).to be(true)
      end
    end
  end

  describe "option combinations" do
    it "accepts multiple valid options" do
      result = run_cli("--help")

      expect(result[:output]).to include("-a, --apply")
      expect(result[:output]).to include("-y, --yes")
      expect(result[:output]).to include("-q, --quiet")
      expect(result[:output]).to include("-v, --verbose")
      expect(result[:output]).to include("--trace")
    end

    it "handles --config option" do
      result = run_cli("--help")

      expect(result[:output]).to include("-c, --config PATH")
    end
  end

  describe "error message formatting" do
    it "uses colored output for errors" do
      result = run_cli("--invalid")

      # Should contain ANSI color codes
      expect(result[:output]).to match(/\e\[38;5;\d+m/)
    end

    it "provides actionable error messages" do
      result = run_cli("push", "--bad-option")

      expect(result[:output]).to include("Invalid option: --bad-option")
      expect(result[:output]).to include("See 'dotsync --help'")
    end

    it "provides helpful suggestions for unknown commands" do
      result = run_cli("unknown")

      expect(result[:output]).to include("Unknown command: 'unknown'")
      expect(result[:output]).to include("See 'dotsync --help' for available commands")
    end
  end

  describe "exit codes" do
    it "exits with 0 on success (--version)" do
      result = run_cli("--version")
      expect(result[:status].exitstatus).to eq(0)
    end

    it "exits with 0 on success (--help)" do
      result = run_cli("--help")
      expect(result[:status].exitstatus).to eq(0)
    end

    it "exits with 1 on invalid option" do
      result = run_cli("--invalid")
      expect(result[:status].exitstatus).to eq(1)
    end

    it "exits with 1 on unknown command" do
      result = run_cli("badcommand")
      expect(result[:status].exitstatus).to eq(1)
    end

    it "exits with 1 when no command provided" do
      result = run_cli
      expect(result[:status].exitstatus).to eq(1)
    end
  end

  describe "regression tests" do
    it "handles the original reported error case: -yes" do
      result = run_cli("push", "--apply", "-yes")

      # Should show clean error, not Ruby exception
      expect(result[:output]).to include("Invalid option: -es")
      expect(result[:output]).not_to include("OptionParser::InvalidOption")
      expect(result[:output]).not_to include("<top (required)>")
      expect(result[:status].exitstatus).to eq(1)
    end

    it "handles multiple invalid short options" do
      result = run_cli("push", "-xyz")

      expect(result[:output]).to include("Invalid option:")
      expect(result[:output]).not_to include("OptionParser::")
      expect(result[:status].exitstatus).to eq(1)
    end
  end
end
