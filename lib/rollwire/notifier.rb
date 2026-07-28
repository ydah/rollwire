# frozen_string_literal: true

require "active_support/notifications"

module Rollwire
  module Notifier
    module_function

    def call(report)
      case report.mode
      when :log
        log(report)
      when :notify
        ActiveSupport::Notifications.instrument(Report::EVENT_NAME, report: report)
      when :raise
        raise IgnoredNestedRollback, report
      end
    end

    def log(report)
      logger = Rollwire.configuration.logger
      logger ||= Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)
      logger ? logger.warn(report.to_s) : Kernel.warn(report.to_s)
    end
  end
end
