# frozen_string_literal: true

module Rollwire
  module OuterLocation
    LOCATION_IVAR = :@rollwire_outer_location

    module_function

    def record(transaction, location)
      transaction.instance_variable_set(LOCATION_IVAR, location)
    end

    def for(transaction)
      transaction.instance_variable_get(LOCATION_IVAR)
    end
  end
end
