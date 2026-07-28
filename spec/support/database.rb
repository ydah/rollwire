# frozen_string_literal: true

require "active_record"

module DatabaseSupport
  module_function

  def configuration
    case ENV.fetch("DB_ADAPTER", "sqlite3")
    when "postgresql"
      {
        adapter: "postgresql",
        database: ENV.fetch("DB_NAME", "rollwire_test"),
        host: ENV.fetch("DB_HOST", "127.0.0.1"),
        password: ENV.fetch("DB_PASSWORD", "postgres"),
        port: ENV.fetch("DB_PORT", 5432),
        username: ENV.fetch("DB_USERNAME", "postgres")
      }
    when "mysql2"
      {
        adapter: "mysql2",
        database: ENV.fetch("DB_NAME", "rollwire_test"),
        host: ENV.fetch("DB_HOST", "127.0.0.1"),
        password: ENV.fetch("DB_PASSWORD", "root"),
        port: ENV.fetch("DB_PORT", 3306),
        username: ENV.fetch("DB_USERNAME", "root")
      }
    else
      { adapter: "sqlite3", database: ":memory:" }
    end
  end

  def establish_connection
    ActiveRecord::Base.establish_connection(configuration)
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table :users, force: true do |table|
        table.string :name, null: false
        table.integer :lock_version, null: false, default: 0
      end
    end
  end
end

DatabaseSupport.establish_connection

class User < ActiveRecord::Base
end

class SecondaryRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(DatabaseSupport.configuration)
end

SecondaryRecord.connection.create_table(:secondary_users, force: true) do |table|
  table.string :name, null: false
end

class SecondaryUser < SecondaryRecord
end
