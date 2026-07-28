# frozen_string_literal: true

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
connection = ActiveRecord::Base.connection
unpatched_transaction = connection.method(:transaction)

require_relative "../lib/rollwire"

puts "Ruby #{RUBY_VERSION}, Active Record #{ActiveRecord.version}, sqlite3"

Benchmark.ips do |benchmark|
  benchmark.config(time: 5, warmup: 2)
  benchmark.report("without Rollwire") { unpatched_transaction.call { nil } }
  benchmark.report("with Rollwire") { connection.transaction { nil } }
  benchmark.compare!
end
