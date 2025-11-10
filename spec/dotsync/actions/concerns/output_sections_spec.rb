# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::OutputSections do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Dotsync::OutputSections
    end
  end
  let(:instance) { test_class.new }

  describe "#compute_output_sections" do
    context "with default options (empty hash)" do
      it "shows all sections by default" do
        result = instance.compute_output_sections({})

        expect(result[:options]).to be(true)
        expect(result[:env_vars]).to be(true)
        expect(result[:mappings_legend]).to be(true)
        expect(result[:mappings]).to be(true)
        expect(result[:differences_legend]).to be(true)
        expect(result[:differences]).to be(true)
      end
    end

    context "with quiet option" do
      it "hides all sections" do
        result = instance.compute_output_sections(quiet: true)

        expect(result[:options]).to be(false)
        expect(result[:env_vars]).to be(false)
        expect(result[:mappings_legend]).to be(false)
        expect(result[:mappings]).to be(false)
        expect(result[:differences_legend]).to be(false)
        expect(result[:differences]).to be(false)
      end
    end

    context "with verbose option" do
      it "shows all sections" do
        result = instance.compute_output_sections(verbose: true)

        expect(result[:options]).to be(true)
        expect(result[:env_vars]).to be(true)
        expect(result[:mappings_legend]).to be(true)
        expect(result[:mappings]).to be(true)
        expect(result[:differences_legend]).to be(true)
        expect(result[:differences]).to be(true)
      end

      it "overrides other hide options" do
        result = instance.compute_output_sections(verbose: true, quiet: true, no_mappings: true)

        expect(result[:options]).to be(true)
        expect(result[:mappings]).to be(true)
        expect(result[:differences]).to be(true)
      end
    end

    context "with only_diff option" do
      it "shows only differences sections" do
        result = instance.compute_output_sections(only_diff: true)

        expect(result[:options]).to be(false)
        expect(result[:env_vars]).to be(false)
        expect(result[:mappings_legend]).to be(false)
        expect(result[:mappings]).to be(false)
        expect(result[:differences_legend]).to be(true)
        expect(result[:differences]).to be(true)
      end
    end

    context "with only_mappings option" do
      it "shows only mappings sections" do
        result = instance.compute_output_sections(only_mappings: true)

        expect(result[:options]).to be(false)
        expect(result[:env_vars]).to be(false)
        expect(result[:mappings_legend]).to be(true)
        expect(result[:mappings]).to be(true)
        expect(result[:differences_legend]).to be(false)
        expect(result[:differences]).to be(false)
      end
    end

    context "with only_config option" do
      it "shows only config sections" do
        result = instance.compute_output_sections(only_config: true)

        expect(result[:options]).to be(true)
        expect(result[:env_vars]).to be(true)
        expect(result[:mappings_legend]).to be(true)
        expect(result[:mappings]).to be(true)
        expect(result[:differences_legend]).to be(false)
        expect(result[:differences]).to be(false)
      end
    end

    context "with no_legend option" do
      it "hides both legend sections" do
        result = instance.compute_output_sections(no_legend: true)

        expect(result[:mappings_legend]).to be(false)
        expect(result[:differences_legend]).to be(false)
        expect(result[:mappings]).to be(true)
        expect(result[:differences]).to be(true)
      end
    end

    context "with no_mappings option" do
      it "hides mappings and mappings legend" do
        result = instance.compute_output_sections(no_mappings: true)

        expect(result[:mappings_legend]).to be(false)
        expect(result[:mappings]).to be(false)
        expect(result[:differences]).to be(true)
      end
    end

    context "with no_diff option" do
      it "hides differences and differences legend" do
        result = instance.compute_output_sections(no_diff: true)

        expect(result[:differences_legend]).to be(false)
        expect(result[:differences]).to be(false)
        expect(result[:mappings]).to be(true)
      end
    end

    context "with no_diff_legend option" do
      it "hides only differences legend" do
        result = instance.compute_output_sections(no_diff_legend: true)

        expect(result[:differences_legend]).to be(false)
        expect(result[:differences]).to be(true)
      end
    end

    context "with combination of options" do
      it "handles no_mappings and no_diff together" do
        result = instance.compute_output_sections(no_mappings: true, no_diff: true)

        expect(result[:mappings]).to be(false)
        expect(result[:differences]).to be(false)
        expect(result[:options]).to be(true)
      end

      it "handles only_diff with no_legend" do
        result = instance.compute_output_sections(only_diff: true, no_legend: true)

        expect(result[:mappings]).to be(false)
        expect(result[:differences]).to be(true)
        expect(result[:differences_legend]).to be(false)
      end

      it "quiet overrides other show options" do
        result = instance.compute_output_sections(quiet: true, only_diff: true)

        expect(result[:differences]).to be(false)
        expect(result[:mappings]).to be(false)
      end
    end
  end
end
