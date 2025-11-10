# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dotsync::BaseConfig do
  let(:config_dir) { File.join("/tmp", "dotsync_base_config_spec") }
  let(:config_path) { File.join(config_dir, "config.toml") }

  before do
    FileUtils.mkdir_p(config_dir)
  end

  after do
    FileUtils.rm_rf(config_dir)
  end

  # Create a concrete test class since BaseConfig is abstract
  let(:test_config_class) do
    Class.new(Dotsync::BaseConfig) do
      private
        def validate!
          validate_section_present!
        end

        def section_name
          "test_section"
        end
    end
  end

  describe "#initialize" do
    context "when config file exists" do
      before do
        File.write(config_path, <<~TOML)
          [test_section]
          key = "value"
        TOML
      end

      it "loads the configuration" do
        config = test_config_class.new(config_path)
        expect(config.to_h).to have_key("test_section")
      end

      it "validates the configuration" do
        expect { test_config_class.new(config_path) }.not_to raise_error
      end
    end

    context "when config file does not exist" do
      it "raises ConfigError with helpful message" do
        expect { test_config_class.new(config_path) }.to raise_error(Dotsync::ConfigError) do |error|
          expect(error.message).to include("Config file not found")
          expect(error.message).to include("dotsync setup")
        end
      end
    end

    context "when required section is missing" do
      before do
        File.write(config_path, <<~TOML)
          [other_section]
          key = "value"
        TOML
      end

      it "raises ConfigError" do
        expect { test_config_class.new(config_path) }.to raise_error(
          Dotsync::ConfigError,
          /No \[test_section\] section found in config file/
        )
      end
    end

    context "when path is relative" do
      let(:relative_path) { "config.toml" }

      before do
        File.write(File.join(Dir.pwd, relative_path), <<~TOML)
          [test_section]
          key = "value"
        TOML
      end

      after do
        FileUtils.rm_f(File.join(Dir.pwd, relative_path))
      end

      it "expands the path to absolute" do
        expect { test_config_class.new(relative_path) }.not_to raise_error
      end
    end
  end

  describe "#to_h" do
    before do
      File.write(config_path, <<~TOML)
        [test_section]
        key1 = "value1"
        key2 = "value2"
      TOML
    end

    it "returns the configuration as a hash" do
      config = test_config_class.new(config_path)
      hash = config.to_h
      expect(hash).to be_a(Hash)
      expect(hash["test_section"]["key1"]).to eq("value1")
      expect(hash["test_section"]["key2"]).to eq("value2")
    end
  end

  describe "abstract methods" do
    let(:base_config_class) do
      Class.new(Dotsync::BaseConfig) do
        def public_validate!
          validate!
        end

        def public_section_name
          section_name
        end
      end
    end

    before do
      File.write(config_path, <<~TOML)
        [test]
        key = "value"
      TOML
    end

    describe "#validate!" do
      it "raises NotImplementedError when not overridden" do
        expect { base_config_class.new(config_path) }.to raise_error(NotImplementedError)
      end
    end

    describe "#section_name" do
      it "raises NotImplementedError when not overridden" do
        allow_any_instance_of(base_config_class).to receive(:validate!)
        config = base_config_class.new(config_path)
        expect { config.public_section_name }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "validation helper methods" do
    let(:test_validation_class) do
      Class.new(Dotsync::BaseConfig) do
        attr_reader :called_methods

        def initialize(path = Dotsync.config_path)
          @called_methods = []
          super
        end

        def test_validate_key_present!(key)
          validate_key_present!(key)
        end

        def test_section
          section
        end

        private
          def validate!
            validate_section_present!
            validate_key_present!("required_key")
          end

          def section_name
            "test_section"
          end
      end
    end

    context "with valid configuration" do
      before do
        File.write(config_path, <<~TOML)
          [test_section]
          required_key = "value"
        TOML
      end

      it "validates without errors" do
        expect { test_validation_class.new(config_path) }.not_to raise_error
      end

      it "provides access to section" do
        config = test_validation_class.new(config_path)
        expect(config.test_section).to eq({ "required_key" => "value" })
      end
    end

    context "with missing required key" do
      before do
        File.write(config_path, <<~TOML)
          [test_section]
          other_key = "value"
        TOML
      end

      it "raises ConfigError" do
        expect { test_validation_class.new(config_path) }.to raise_error(
          Dotsync::ConfigError,
          /does not include key 'required_key'/
        )
      end
    end
  end

  describe "PathUtils inclusion" do
    it "includes PathUtils module" do
      expect(described_class.included_modules).to include(Dotsync::PathUtils)
    end
  end
end
