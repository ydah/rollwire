# frozen_string_literal: true

module Rollwire
  class Configuration
    MODES = %i[log notify raise].freeze

    attr_reader :backtrace_lines, :capture_outer_location, :count_writes, :ignore_if,
                :min_writes, :mode, :strict_patching
    attr_accessor :logger

    def initialize
      @backtrace_lines = 10
      @capture_outer_location = true
      @count_writes = true
      @ignore_if = nil
      @min_writes = 1
      @mode = :log
      @mode_explicitly_configured = false
      @strict_patching = false
      @logger = nil
    end

    def mode=(value)
      raise ConfigurationError, "mode must be one of: #{MODES.join(', ')}" unless MODES.include?(value)

      @mode = value
      @mode_explicitly_configured = true
    end

    def min_writes=(value)
      raise ConfigurationError, "min_writes must be a non-negative Integer" unless value.is_a?(Integer) && value >= 0

      @min_writes = value
    end

    def backtrace_lines=(value)
      unless value.is_a?(Integer) && value.positive?
        raise ConfigurationError, "backtrace_lines must be a positive Integer"
      end

      @backtrace_lines = value
    end

    def count_writes=(value)
      @count_writes = validate_boolean(:count_writes, value)
    end

    def capture_outer_location=(value)
      @capture_outer_location = validate_boolean(:capture_outer_location, value)
    end

    def strict_patching=(value)
      @strict_patching = validate_boolean(:strict_patching, value)
    end

    def ignore_if=(callable)
      raise ConfigurationError, "ignore_if must be callable or nil" unless callable.nil? || callable.respond_to?(:call)

      @ignore_if = callable
    end

    def apply_environment_default!(test:)
      @mode = :raise if test && !@mode_explicitly_configured
    end

    private

    def validate_boolean(name, value)
      return value if [true, false].include?(value)

      raise ConfigurationError, "#{name} must be true or false"
    end
  end
end
