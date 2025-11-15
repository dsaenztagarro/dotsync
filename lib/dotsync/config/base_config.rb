# frozen_string_literal: true

module Dotsync
  # BaseConfig serves as an abstract class to define the structure
  # and validation rules for configuration files in the Dotsync system.
  class BaseConfig
    include Dotsync::PathUtils

    # Initialize the BaseConfig with the provided path.
    # Loads the TOML configuration file and validates it.
    # Uses ConfigCache for improved performance.
    #
    # @param [String] path The file path to the configuration file.
    def initialize(path = Dotsync.config_path)
      absolute_path = File.expand_path(path)

      unless File.exist?(absolute_path)
        raise Dotsync::ConfigError,
          "Config file not found: #{absolute_path}\n\n" \
          "To create a default configuration file, run:\n" \
          "  dotsync setup"
      end

      @config = load_config(absolute_path)
      validate!
    end

    def to_h
      @config
    end

    private
      # Loads configuration from file, using cache when possible
      #
      # @param [String] path The file path to the configuration file.
      # @return [Hash] The parsed configuration
      def load_config(path)
        require_relative "../utils/config_cache"
        ConfigCache.new(path).load
      end

      # Validates the configuration file.
      #
      # @raise [NotImplementedError] if not implemented by a subclass.
      def validate!
        raise NotImplementedError
      end

      # Returns the name of the section to validate.
      #
      # @return [String] The section name.
      # @raise [NotImplementedError] if not implemented by a subclass.
      def section_name
        raise NotImplementedError
      end

      # Retrieves the configuration section.
      #
      # @return [Hash] The section of the configuration file.
      def section
        @config[section_name]
      end

      # Validates if the required section is present in the configuration.
      #
      # @raise [Dotsync::ConfigError] if the section is missing.
      def validate_section_present!
        unless @config.key?(section_name)
          raise_error "No [#{section_name}] section found in config file"
        end
      end

      # Validates if a specific key is present in the section.
      #
      # @param [String] key The key to validate.
      # @raise [Dotsync::ConfigError] if the key is missing.
      def validate_key_present!(key)
        unless section.key?(key)
          raise_error "[#{section_name}] section does not include key '#{key}'"
        end
      end

      # Raises a configuration error with the provided message.
      #
      # @param [String] message The error message to raise.
      # @raise [Dotsync::ConfigError] Always raises this error with the given message.
      def raise_error(message)
        raise Dotsync::ConfigError, "Config Error: #{message}"
      end
  end
end
