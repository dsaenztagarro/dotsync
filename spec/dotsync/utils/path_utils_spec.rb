# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::PathUtils do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Dotsync::PathUtils
    end
  end
  let(:test_instance) { test_class.new }

  describe "#expand_env_vars" do
    before do
      ENV["TEST_VAR"] = "/test/path"
      ENV["HOME_VAR"] = "/home/user"
    end

    after do
      ENV.delete("TEST_VAR")
      ENV.delete("HOME_VAR")
    end

    it "expands single environment variable" do
      result = test_instance.expand_env_vars("$TEST_VAR/file.txt")
      expect(result).to eq("/test/path/file.txt")
    end

    it "expands multiple environment variables" do
      result = test_instance.expand_env_vars("$HOME_VAR/$TEST_VAR/file.txt")
      expect(result).to eq("/home/user//test/path/file.txt")
    end

    it "returns path unchanged when no environment variables" do
      result = test_instance.expand_env_vars("/regular/path/file.txt")
      expect(result).to eq("/regular/path/file.txt")
    end

    it "handles undefined environment variable by removing it" do
      result = test_instance.expand_env_vars("$UNDEFINED_VAR/file.txt")
      expect(result).to eq("/file.txt")
    end
  end

  describe "#extract_env_vars" do
    it "extracts single environment variable" do
      result = test_instance.extract_env_vars("$HOME/file.txt")
      expect(result).to eq(["HOME"])
    end

    it "extracts multiple environment variables" do
      result = test_instance.extract_env_vars("$HOME/$USER/file.txt")
      expect(result).to eq(["HOME", "USER"])
    end

    it "returns empty array when no environment variables" do
      result = test_instance.extract_env_vars("/regular/path/file.txt")
      expect(result).to eq([])
    end

    it "extracts duplicate environment variables separately" do
      result = test_instance.extract_env_vars("$HOME/$HOME/file.txt")
      expect(result).to eq(["HOME", "HOME"])
    end
  end

  describe "#colorize_env_vars" do
    it "colorizes single environment variable" do
      result = test_instance.colorize_env_vars("$HOME/file.txt")
      expect(result).to include("\e[38;5;104m$HOME\e[0m")
      expect(result).to match(/\$HOME.*\/file\.txt/)
    end

    it "colorizes multiple environment variables" do
      result = test_instance.colorize_env_vars("$HOME/$USER/file.txt")
      expect(result).to include("\e[38;5;104m$HOME\e[0m")
      expect(result).to include("\e[38;5;104m$USER\e[0m")
    end

    it "returns path unchanged when no environment variables" do
      result = test_instance.colorize_env_vars("/regular/path/file.txt")
      expect(result).to eq("/regular/path/file.txt")
    end
  end

  describe "#relative_to_absolute" do
    it "converts single relative path to absolute" do
      result = test_instance.relative_to_absolute(["file.txt"], "/base")
      expect(result).to eq(["/base/file.txt"])
    end

    it "converts multiple relative paths to absolute" do
      result = test_instance.relative_to_absolute(["file1.txt", "dir/file2.txt"], "/base")
      expect(result).to eq(["/base/file1.txt", "/base/dir/file2.txt"])
    end

    it "handles empty array" do
      result = test_instance.relative_to_absolute([], "/base")
      expect(result).to eq([])
    end

    it "handles paths with subdirectories" do
      result = test_instance.relative_to_absolute(["a/b/c.txt"], "/base")
      expect(result).to eq(["/base/a/b/c.txt"])
    end
  end

  describe "#path_is_parent_or_same?" do
    it "returns true when paths are the same" do
      result = test_instance.path_is_parent_or_same?("/tmp/test", "/tmp/test")
      expect(result).to be true
    end

    it "returns true when first path is parent of second" do
      result = test_instance.path_is_parent_or_same?("/tmp", "/tmp/test/file.txt")
      expect(result).to be true
    end

    it "returns false when first path is not parent of second" do
      result = test_instance.path_is_parent_or_same?("/tmp/a", "/tmp/b/file.txt")
      expect(result).to be false
    end

    it "returns false when first path is child of second" do
      result = test_instance.path_is_parent_or_same?("/tmp/test/file.txt", "/tmp")
      expect(result).to be false
    end

    it "handles relative paths by expanding them" do
      Dir.chdir("/tmp") do
        result = test_instance.path_is_parent_or_same?(".", "subdir")
        expect(result).to be true
      end
    end
  end

  describe "#translate_tmp_path" do
    context "on macOS (darwin platform)" do
      it "translates /tmp to /private/tmp when on darwin" do
        if RUBY_PLATFORM.include?("darwin")
          result = test_instance.translate_tmp_path("/tmp/file.txt")
          expect(result).to eq("/private/tmp/file.txt")
        else
          skip "Test only runs on macOS"
        end
      end

      it "does not affect paths not starting with /tmp" do
        result = test_instance.translate_tmp_path("/home/user/file.txt")
        expect(result).to eq("/home/user/file.txt")
      end

      it "does not affect paths containing /tmp but not at start" do
        result = test_instance.translate_tmp_path("/home/tmp/file.txt")
        expect(result).to eq("/home/tmp/file.txt")
      end
    end

    context "on non-macOS platforms" do
      it "does not translate /tmp paths when not on darwin" do
        unless RUBY_PLATFORM.include?("darwin")
          result = test_instance.translate_tmp_path("/tmp/file.txt")
          expect(result).to eq("/tmp/file.txt")
        else
          skip "Test only runs on non-macOS"
        end
      end
    end
  end

  describe "#sanitize_path" do
    before do
      ENV["TEST_HOME"] = "/home/test"
    end

    after do
      ENV.delete("TEST_HOME")
    end

    it "expands environment variables and absolute path" do
      result = test_instance.sanitize_path("$TEST_HOME/file.txt")
      expect(result).to eq("/home/test/file.txt")
    end

    it "expands relative paths" do
      result = test_instance.sanitize_path("./file.txt")
      expect(result).to include("file.txt")
      expect(result).to start_with("/")
    end

    context "on macOS (darwin platform)" do
      it "translates /tmp to /private/tmp when on darwin" do
        if RUBY_PLATFORM.include?("darwin")
          result = test_instance.sanitize_path("/tmp/file.txt")
          expect(result).to eq("/private/tmp/file.txt")
        else
          skip "Test only runs on macOS"
        end
      end
    end

    context "on non-macOS platforms" do
      it "does not translate /tmp paths when not on darwin" do
        unless RUBY_PLATFORM.include?("darwin")
          result = test_instance.sanitize_path("/tmp/file.txt")
          expect(result).to eq("/tmp/file.txt")
        else
          skip "Test only runs on non-macOS"
        end
      end
    end
  end

  describe "ENV_VARS_COLOR constant" do
    it "is defined with value 104" do
      expect(Dotsync::PathUtils::ENV_VARS_COLOR).to eq(104)
    end
  end
end
