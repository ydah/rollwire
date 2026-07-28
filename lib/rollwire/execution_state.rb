# frozen_string_literal: true

module Rollwire
  module ExecutionState
    KEY_PREFIX = "rollwire"

    module_function

    def read(key)
      backend[storage_key(key)]
    end

    def write(key, value)
      backend[storage_key(key)] = value
    end

    def delete(key)
      backend.delete(storage_key(key))
    end

    def backend
      ActiveSupport::IsolatedExecutionState
    end

    def storage_key(key)
      :"#{KEY_PREFIX}.#{key}"
    end
  end
end
