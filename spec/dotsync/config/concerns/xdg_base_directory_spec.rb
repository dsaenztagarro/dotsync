# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::XDGBaseDirectory do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Dotsync::XDGBaseDirectory
    end
  end
  let(:instance) { test_class.new }

  describe "#xdg_data_home" do
    context "when XDG_DATA_HOME is set" do
      before do
        ENV["XDG_DATA_HOME"] = "/custom/data"
      end

      after do
        ENV.delete("XDG_DATA_HOME")
      end

      it "returns the custom path" do
        expect(instance.xdg_data_home).to eq("/custom/data")
      end
    end

    context "when XDG_DATA_HOME is not set" do
      before do
        ENV.delete("XDG_DATA_HOME")
      end

      it "returns default path" do
        expected = File.expand_path("~/.local/share")
        expect(instance.xdg_data_home).to eq(expected)
      end
    end
  end

  describe "#xdg_config_home" do
    context "when XDG_CONFIG_HOME is set" do
      before do
        ENV["XDG_CONFIG_HOME"] = "/custom/config"
      end

      after do
        ENV.delete("XDG_CONFIG_HOME")
      end

      it "returns the custom path" do
        expect(instance.xdg_config_home).to eq("/custom/config")
      end
    end

    context "when XDG_CONFIG_HOME is not set" do
      before do
        ENV.delete("XDG_CONFIG_HOME")
      end

      it "returns default path" do
        expected = File.expand_path("~/.config")
        expect(instance.xdg_config_home).to eq(expected)
      end
    end
  end

  describe "#xdg_cache_home" do
    context "when XDG_CACHE_HOME is set" do
      before do
        ENV["XDG_CACHE_HOME"] = "/custom/cache"
      end

      after do
        ENV.delete("XDG_CACHE_HOME")
      end

      it "returns the custom path" do
        expect(instance.xdg_cache_home).to eq("/custom/cache")
      end
    end

    context "when XDG_CACHE_HOME is not set" do
      before do
        ENV.delete("XDG_CACHE_HOME")
      end

      it "returns default path" do
        expected = File.expand_path("~/.cache")
        expect(instance.xdg_cache_home).to eq(expected)
      end
    end
  end

  describe "#xdg_bin_home" do
    context "when XDG_BIN_HOME is set" do
      before do
        ENV["XDG_BIN_HOME"] = "/custom/bin"
      end

      after do
        ENV.delete("XDG_BIN_HOME")
      end

      it "returns the custom path" do
        expect(instance.xdg_bin_home).to eq("/custom/bin")
      end
    end

    context "when XDG_BIN_HOME is not set" do
      before do
        ENV.delete("XDG_BIN_HOME")
      end

      it "returns default path" do
        expected = File.expand_path("~/.local/bin")
        expect(instance.xdg_bin_home).to eq(expected)
      end
    end
  end
end
