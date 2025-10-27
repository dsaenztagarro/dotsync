# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Logger do
  let(:output) { StringIO.new } # Capture output for testing
  let(:logger) { described_class.new(output) }

  describe "#info" do
    it "logs a message with default color, bold and icon" do
      logger.info("This is an info message")

      expect(output.string).to include("This is an info message")
      expect(output.string).to include("\e[38;5;103m") # Check for info color
      expect(output.string).to include("\e[1m") # Check for bold
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:info]) # Check for info icon
    end

    it "logs a message without bold and different icon" do
      logger.info("Customized message", icon: :config, bold: false)

      expect(output.string).to include("Customized message")
      expect(output.string).to_not include("\e[1m") # Check for bold
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:config]) # Check for info icon
    end
  end

  describe "#action" do
    it "logs a message with default color, bold and icon" do
      logger.action("This is an action message")

      expect(output.string).to include("This is an action message")
      expect(output.string).to include("\e[38;5;153m") # Check for action color
      expect(output.string).to include("\e[1m") # Check for bold
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:console]) # Check for action icon
    end

    it "logs a message without bold and different icon" do
      logger.action("Customized message", icon: :config, bold: false)

      expect(output.string).to include("Customized message")
      expect(output.string).to include("\e[38;5;153m") # Check for action color
      expect(output.string).to_not include("\e[1m") # Check for bold
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:config]) # Check for info icon
    end
  end

  describe "#error" do
    it "logs a message with default color, bold and icon" do
      logger.error("This is an error message")

      expect(output.string).to include("This is an error message")
      expect(output.string).to include("\e[38;5;196m") # Check for error color
      expect(output.string).to include("\e[1m") # Check for bold
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:error]) # Check for error icon
    end

    it "logs a message without bold and different icon" do
      logger.action("Customized message", icon: :config, bold: false)

      expect(output.string).to include("Customized message")
      expect(output.string).to include("\e[38;5;153m") # Check for action color
      expect(output.string).to_not include("\e[1m") # Check for bold
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:config]) # Check for info icon
    end
  end

  describe "#log" do
    it "logs a message without providing options" do
      logger.log("Generic log message")

      expect(output.string).to include("Generic log message")
      expect(output.string).to_not include("\e[38;5;103m") # Check for info color
      expect(output.string).to_not include("\e[1m") # No bold expected
      expect(output.string).to_not include("\e[0m") # Reset color sequence
    end

    it "logs a message with the provided color, bold and icon" do
      logger.log("Generic log message", color: 103, bold: true, icon: :info)

      expect(output.string).to include("Generic log message")
      expect(output.string).to include("\e[38;5;103m") # Check for info color
      expect(output.string).to include("\e[1m") # No bold expected
      expect(output.string).to include(Dotsync::Icons::MAPPINGS[:info]) # Check for info icon
      expect(output.string).to include("\e[0m") # Reset color sequence
    end
  end
end
