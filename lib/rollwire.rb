# frozen_string_literal: true

require "active_record"
require "active_support/isolated_execution_state"
require "pathname"

require_relative "rollwire/version"
require_relative "rollwire/configuration"
require_relative "rollwire/errors"
require_relative "rollwire/execution_state"
require_relative "rollwire/outer_location"
require_relative "rollwire/report"
require_relative "rollwire/notifier"
require_relative "rollwire/write_counter"
require_relative "rollwire/patches/database_statements"
require_relative "rollwire/patches/transaction_manager"
require_relative "rollwire/patcher"

module Rollwire
  class << self
    attr_reader :configuration

    def configure
      yield configuration
      configuration
    end

    def enable!
      @enabled = true
      install!
    end

    def disable!
      @enabled = false
    end

    def enabled?
      @enabled && !suppressed?
    end

    def suppress
      previous_depth = suppression_depth
      ExecutionState.write(:suppression_depth, previous_depth + 1)
      yield
    ensure
      restore_suppression_depth(previous_depth)
    end

    def install!
      Patcher.install!
      @enabled = true if @enabled.nil?
      true
    rescue StandardError => e
      raise if configuration.strict_patching

      @enabled = false
      warn_internal_error(e)
      false
    end

    def handle_ignored_rollback(connection:, inner_location:, writes:)
      return if configuration.count_writes && writes < configuration.min_writes

      report = Report.new(
        inner_location: inner_location,
        mode: configuration.mode,
        outer_location: OuterLocation.for(connection.current_transaction),
        writes: writes
      )
      return if configuration.ignore_if&.call(report)

      Notifier.call(report)
      report
    end

    def caller_location
      locations = caller_locations(2, [configuration.backtrace_lines * 20, 20].max)
      location = locations.find { |candidate| application_location?(candidate.path) }
      format_location(location)
    end

    def warn_internal_error(error)
      message = "[Rollwire] internal error: #{error.class}: #{error.message}"
      logger = configuration.logger || rails_logger
      logger ? logger.warn(message) : Kernel.warn(message)
    rescue StandardError
      Kernel.warn(message)
    rescue Exception # rubocop:disable Lint/RescueException
      nil
    end

    def reset_configuration!
      @configuration = Configuration.new
      @enabled = true
    end

    private

    def application_location?(path)
      !path.include?("/active_record/") &&
        !path.include?("/active_support/") &&
        !path.include?("/lib/rollwire")
    end

    def format_location(location)
      return unless location

      path = Pathname.new(location.absolute_path || location.path)
      root = Pathname.new(Dir.pwd)
      path = path.relative_path_from(root) if path.to_s.start_with?("#{root}/")
      "#{path}:#{location.lineno}"
    rescue ArgumentError
      "#{location.path}:#{location.lineno}"
    end

    def rails_logger
      Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)
    end

    def restore_suppression_depth(depth)
      if depth.zero?
        ExecutionState.delete(:suppression_depth)
      else
        ExecutionState.write(:suppression_depth, depth)
      end
    end

    def suppressed?
      suppression_depth.positive?
    end

    def suppression_depth
      ExecutionState.read(:suppression_depth) || 0
    end
  end

  reset_configuration!
end

require_relative "rollwire/railtie" if defined?(Rails::Railtie)

Rollwire.install!
