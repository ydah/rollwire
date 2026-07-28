# frozen_string_literal: true

require "rollwire"
require_relative "support/database"
require_relative "support/notification_collector"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    Rollwire.reset_configuration!
    Rollwire::WriteCounter.reset!
    User.delete_all
    SecondaryUser.delete_all
  end
end
