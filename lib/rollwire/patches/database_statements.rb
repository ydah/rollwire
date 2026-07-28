# frozen_string_literal: true

module Rollwire
  module DatabaseStatementsPatch
    def transaction(**options, &block)
      joined = Rollwire.enabled? &&
               open_transactions.positive? &&
               !options[:requires_new] &&
               current_transaction.joinable?

      return super(**options, &block) unless joined && block

      inner_location = Rollwire.caller_location
      pushed = false
      begin
        WriteCounter.push_frame(self)
        pushed = true
      rescue StandardError => e
        Rollwire.warn_internal_error(e)
        return super(**options, &block)
      end

      super(**options) do |*arguments|
        block.call(*arguments)
      rescue ActiveRecord::Rollback => e
        report_ignored_rollback(inner_location)
        raise e
      end
    ensure
      safely_pop_write_frame if pushed
    end

    private

    def report_ignored_rollback(inner_location)
      Rollwire.handle_ignored_rollback(
        connection: self,
        inner_location: inner_location,
        writes: WriteCounter.current_writes(self)
      )
    rescue IgnoredNestedRollback
      raise
    rescue StandardError => e
      Rollwire.warn_internal_error(e)
    end

    def safely_pop_write_frame
      WriteCounter.pop_frame(self)
    rescue StandardError => e
      Rollwire.warn_internal_error(e)
    end
  end
end
