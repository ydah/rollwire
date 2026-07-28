# frozen_string_literal: true

module Rollwire
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class PatchingError < Error; end

  class IgnoredNestedRollback < Error
    attr_reader :report

    def initialize(report)
      @report = report
      super(report.to_s)
    end
  end
end
