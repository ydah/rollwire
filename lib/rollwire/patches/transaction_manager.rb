# frozen_string_literal: true

module Rollwire
  module TransactionManagerPatch
    def begin_transaction(...)
      location = capture_outer_location
      transaction = super
      record_outer_location(transaction, location)
      transaction
    end

    private

    def capture_outer_location
      return unless Rollwire.enabled?
      return unless Rollwire.configuration.capture_outer_location

      Rollwire.caller_location
    rescue StandardError => e
      Rollwire.warn_internal_error(e)
      nil
    end

    def record_outer_location(transaction, location)
      OuterLocation.record(transaction, location) if location
    rescue StandardError => e
      Rollwire.warn_internal_error(e)
    end
  end
end
