# frozen_string_literal: true

module Rollwire
  module Patcher
    module_function

    def install!
      validate!
      install_database_statements_patch
      install_transaction_manager_patch
      WriteCounter.start!
    end

    def installed?
      database_statements.ancestors.include?(DatabaseStatementsPatch) &&
        transaction_manager.ancestors.include?(TransactionManagerPatch)
    end

    def validate!
      validate_method(
        database_statements,
        :transaction,
        required_keywords: %i[requires_new isolation joinable],
        requires_block: true
      )
      validate_method(transaction_manager, :begin_transaction, required_keywords: %i[isolation joinable])
    end

    def install_database_statements_patch
      return if database_statements.ancestors.include?(DatabaseStatementsPatch)

      database_statements.prepend(DatabaseStatementsPatch)
    end
    private_class_method :install_database_statements_patch

    def install_transaction_manager_patch
      return if transaction_manager.ancestors.include?(TransactionManagerPatch)

      transaction_manager.prepend(TransactionManagerPatch)
    end
    private_class_method :install_transaction_manager_patch

    def validate_method(owner, name, required_keywords:, requires_block: false)
      raise PatchingError, "#{owner}##{name} is unavailable" unless owner.method_defined?(name)

      parameters = owner.instance_method(name).parameters
      keyword_names = parameters.filter_map { |type, keyword| keyword if %i[key keyreq].include?(type) }
      accepts_all_keywords = parameters.any? { |type, _| type == :keyrest }
      keywords_compatible = accepts_all_keywords || (required_keywords - keyword_names).empty?
      block_compatible = !requires_block || parameters.any? { |type, _| type == :block }
      return if keywords_compatible && block_compatible

      raise PatchingError, "#{owner}##{name} has an unsupported signature: #{parameters.inspect}"
    end
    private_class_method :validate_method

    def database_statements
      ActiveRecord::ConnectionAdapters::DatabaseStatements
    end
    private_class_method :database_statements

    def transaction_manager
      ActiveRecord::ConnectionAdapters::TransactionManager
    end
    private_class_method :transaction_manager
  end
end
