# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::BaseAction do
  let(:config) { instance_double("Dotsync::BaseConfig") }
  let(:logger) { instance_double("Dotsync::Logger") }
  let(:action) { described_class.new(config, logger) }

  describe "#initialize" do
    it "sets config and logger" do
      expect(action.logger).to eq(logger)
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      expect { action.execute }.to raise_error(NotImplementedError)
    end
  end

  describe "delegated methods" do
    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:action)
    end

    describe "#info" do
      it "delegates to logger.info" do
        action.info("test message", icon: :test)
        expect(logger).to have_received(:info).with("test message", icon: :test)
      end
    end

    describe "#action" do
      it "delegates to logger.action" do
        action.action("test action", icon: :test)
        expect(logger).to have_received(:action).with("test action", icon: :test)
      end
    end
  end

  describe "#show_options" do
    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:log)
    end

    context "when apply is true" do
      it "displays options with apply as TRUE" do
        action.send(:show_options, { apply: true })

        expect(logger).to have_received(:info).with("Options:", icon: :options)
        expect(logger).to have_received(:log).with("  Apply: TRUE")
        expect(logger).to have_received(:log).with("")
      end
    end

    context "when apply is false" do
      it "displays options with apply as FALSE" do
        action.send(:show_options, { apply: false })

        expect(logger).to have_received(:info).with("Options:", icon: :options)
        expect(logger).to have_received(:log).with("  Apply: FALSE")
        expect(logger).to have_received(:log).with("")
      end
    end
  end

  describe "PathUtils inclusion" do
    it "includes PathUtils module" do
      expect(described_class.included_modules).to include(Dotsync::PathUtils)
    end
  end
end
