# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::Diff do
  describe "#initialize" do
    context "with no arguments" do
      it "initializes with empty arrays" do
        diff = described_class.new
        expect(diff.additions).to eq([])
        expect(diff.modifications).to eq([])
        expect(diff.removals).to eq([])
      end
    end

    context "with additions only" do
      it "sets additions and leaves others empty" do
        diff = described_class.new(additions: ["file1.txt", "file2.txt"])
        expect(diff.additions).to eq(["file1.txt", "file2.txt"])
        expect(diff.modifications).to eq([])
        expect(diff.removals).to eq([])
      end
    end

    context "with modifications only" do
      it "sets modifications and leaves others empty" do
        diff = described_class.new(modifications: ["config.yml"])
        expect(diff.additions).to eq([])
        expect(diff.modifications).to eq(["config.yml"])
        expect(diff.removals).to eq([])
      end
    end

    context "with removals only" do
      it "sets removals and leaves others empty" do
        diff = described_class.new(removals: ["old_file.rb"])
        expect(diff.additions).to eq([])
        expect(diff.modifications).to eq([])
        expect(diff.removals).to eq(["old_file.rb"])
      end
    end

    context "with all types of changes" do
      it "sets all three categories" do
        diff = described_class.new(
          additions: ["new.txt"],
          modifications: ["updated.txt"],
          removals: ["deleted.txt"]
        )
        expect(diff.additions).to eq(["new.txt"])
        expect(diff.modifications).to eq(["updated.txt"])
        expect(diff.removals).to eq(["deleted.txt"])
      end
    end
  end

  describe "#any?" do
    context "with no changes" do
      it "returns false" do
        diff = described_class.new
        expect(diff.any?).to be false
      end
    end

    context "with additions only" do
      it "returns true" do
        diff = described_class.new(additions: ["file.txt"])
        expect(diff.any?).to be true
      end
    end

    context "with modifications only" do
      it "returns true" do
        diff = described_class.new(modifications: ["file.txt"])
        expect(diff.any?).to be true
      end
    end

    context "with removals only" do
      it "returns true" do
        diff = described_class.new(removals: ["file.txt"])
        expect(diff.any?).to be true
      end
    end

    context "with multiple types of changes" do
      it "returns true" do
        diff = described_class.new(
          additions: ["a.txt"],
          modifications: ["b.txt"]
        )
        expect(diff.any?).to be true
      end
    end
  end

  describe "#empty?" do
    context "with no changes" do
      it "returns true" do
        diff = described_class.new
        expect(diff.empty?).to be true
      end
    end

    context "with additions only" do
      it "returns false" do
        diff = described_class.new(additions: ["file.txt"])
        expect(diff.empty?).to be false
      end
    end

    context "with modifications only" do
      it "returns false" do
        diff = described_class.new(modifications: ["file.txt"])
        expect(diff.empty?).to be false
      end
    end

    context "with removals only" do
      it "returns false" do
        diff = described_class.new(removals: ["file.txt"])
        expect(diff.empty?).to be false
      end
    end

    context "with all types of changes" do
      it "returns false" do
        diff = described_class.new(
          additions: ["a.txt"],
          modifications: ["b.txt"],
          removals: ["c.txt"]
        )
        expect(diff.empty?).to be false
      end
    end
  end

  describe "#any? and #empty? are opposites" do
    it "returns opposite boolean values" do
      empty_diff = described_class.new
      expect(empty_diff.any?).to eq(!empty_diff.empty?)

      non_empty_diff = described_class.new(additions: ["file.txt"])
      expect(non_empty_diff.any?).to eq(!non_empty_diff.empty?)
    end
  end
end
