# frozen_string_literal: true

module Rollwire
  class Report
    EVENT_NAME = "ignored_rollback.rollwire"

    attr_reader :inner_location, :mode, :outer_location, :writes

    def initialize(inner_location:, mode:, outer_location:, writes:)
      @inner_location = inner_location
      @mode = mode
      @outer_location = outer_location
      @writes = writes
    end

    def to_s
      <<~REPORT.chomp
        Rollwire::IgnoredNestedRollback

        ActiveRecord::Rollback was raised inside a transaction
        that joined an existing transaction.

        #{write_consequence}

        Inner transaction:
          #{inner_location || '(unknown)'}

        Outer transaction:
          #{outer_location || '(not captured)'}

        Use `requires_new: true` to roll back only the inner block,
        or propagate the failure to the outer transaction.
      REPORT
    end

    private

    def write_consequence
      subject = writes == 1 ? "The 1 write" : "The #{writes} writes"
      if mode == :raise
        "#{subject} executed inside this block would not have been rolled back " \
          "(this raise rolled back the outer transaction instead)."
      else
        "#{subject} executed inside this block will not be rolled back."
      end
    end
  end
end
