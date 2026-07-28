# Rollwire

Rollwire detects `ActiveRecord::Rollback` exceptions that Rails
silently ignores when a nested transaction joins its parent without creating a
savepoint.

## The problem

Both records are committed in this example:

```ruby
User.transaction do
  User.create!(name: "Kotori")

  User.transaction do
    User.create!(name: "Nemu")
    raise ActiveRecord::Rollback
  end
end
```

The inner call joins the existing transaction. Rails catches
`ActiveRecord::Rollback`, but there is no savepoint to roll back and the
exception does not reach the outer block. This is documented behavior in
[Active Record transactions](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#method-i-transaction).

Rollwire reports this only when the joined block executes a write
(`INSERT`, `UPDATE`, `DELETE`, or `SELECT ... FOR UPDATE`) before raising the
rollback.

## Installation

Until version 0.1.0 is published on RubyGems, install from the repository:

```ruby
gem "rollwire", github: "ydah/rollwire"
```

Then run:

```console
bundle install
```

The gem installs its Active Record patches when required.

## Configuration

Add an initializer:

```ruby
Rollwire.configure do |config|
  config.mode = :raise
  config.min_writes = 1
  config.count_writes = true
  config.capture_outer_location = true
  config.backtrace_lines = 10
  config.strict_patching = false
  config.ignore_if = nil
end
```

The Railtie defaults to `:raise` in `test` and `:log` in other Rails
environments. Setting `mode` explicitly overrides the environment default.

| Setting | Default | Purpose |
| --- | --- | --- |
| `mode` | `:raise` in test, otherwise `:log` | Select reporting behavior |
| `min_writes` | `1` | Minimum matching SQL statements before reporting |
| `count_writes` | `true` | Disable to report even when no write was observed |
| `capture_outer_location` | `true` | Record the real outer transaction location |
| `backtrace_lines` | `10` | Control the amount of stack inspected for locations |
| `strict_patching` | `false` | Raise instead of warning and disabling on an incompatible Active Record API |
| `ignore_if` | `nil` | Callable that suppresses selected reports |

### Modes

- `:log` writes the report to `Rails.logger` (or stderr). It re-raises the
  original rollback inside Rails, so application behavior and final database
  state remain unchanged.
- `:notify` emits `ignored_rollback.rollwire` with the report in
  `payload[:report]`. Database behavior is unchanged.
- `:raise` replaces the ignored rollback with
  `Rollwire::IgnoredNestedRollback`. This escapes the joined block
  and rolls back the outer transaction.

`:raise` is intentionally test-only: it changes the final database state. In
the opening example, `:log` and `:notify` leave both Kotori and Nemu committed;
`:raise` leaves neither record committed.

Subscribe to notification mode with:

```ruby
ActiveSupport::Notifications.subscribe(
  "ignored_rollback.rollwire"
) do |*, payload|
  report = payload.fetch(:report)
  ErrorTracker.notify(report.to_s)
end
```

### Suppression

Suppress a known-safe region:

```ruby
Rollwire.suppress do
  LegacyImporter.call
end
```

Or ignore reports selectively:

```ruby
Rollwire.configure do |config|
  config.ignore_if = lambda do |report|
    report.inner_location&.include?("lib/legacy/")
  end
end
```

`Rollwire.disable!` and `Rollwire.enable!` disable or
enable detection globally.

## Transactional tests and fixtures

Rails transactional tests use a non-joinable outer transaction. This creates an
important difference from production:

- An application transaction directly inside the test transaction gets a
  savepoint. Its rollback works, so there is no ignored rollback for this gem to
  detect—even if the same single application transaction would be unsafe in
  production.
- With two application transaction levels (service A calls service B), the
  first application transaction is a joinable savepoint and the second joins
  it. Rollwire detects a rollback in the second level.

Installing this gem therefore does not make a single-transaction fixture test
prove production behavior. It detects the problem only on execution paths where
a joined nested transaction actually occurs.

## Reports and safety

A log report identifies the inner and real outer transaction call sites:

```text
Rollwire::IgnoredNestedRollback

ActiveRecord::Rollback was raised inside a transaction
that joined an existing transaction.

The 2 writes executed inside this block will not be rolled back.

Inner transaction:
  app/services/create_user.rb:24

Outer transaction:
  app/services/import_users.rb:61

Use `requires_new: true` to roll back only the inner block,
or propagate the failure to the outer transaction.
```

Write frames are isolated by Active Support execution context and database
connection. SQL classification uses the payload SQL, not its event name, so
`update_columns` and raw `execute` writes are included.

Reporting failures are converted to warnings. Other than the dedicated
exception in `:raise` mode, instrumentation errors do not replace the original
rollback or change transaction behavior.

## Isolator

[Isolator](https://github.com/palkan/isolator) detects non-atomic side effects
and can limit nested transaction depth. Rollwire has a narrower
purpose: it detects a rollback that was specifically ignored because a nested
Active Record transaction joined its parent. The gems are complementary.

## Compatibility

The CI support matrix is:

| Ruby | Active Record 7.1 | Active Record 7.2 | Active Record 8.0 |
| --- | :---: | :---: | :---: |
| 3.1 | ✓ | ✓ | — |
| 3.2 | ✓ | ✓ | ✓ |
| 3.3 | ✓ | ✓ | ✓ |

Ruby 3.1 with Active Record 8.0 is excluded because Active Record 8.0 requires
Ruby 3.2 or newer. PostgreSQL and MySQL each have an Active Record 8.0 smoke
job. Rails main runs as an allowed-failure forward-compatibility job.

The patches target private Active Record transaction APIs. Unsupported API
shapes produce a warning and automatically disable detection unless
`strict_patching` is enabled.

## Performance

The non-nested path only checks whether a transaction is already open and then
immediately delegates to Active Record.

`benchmark/non_nested_transaction.rb` measured the following on Ruby 4.0.0,
Active Record 8.0.2, and SQLite3:

| Case | Iterations/second | Time/iteration |
| --- | ---: | ---: |
| Without Rollwire | 31,069.5 | 32.19 μs |
| With Rollwire | 30,310.6 | 32.99 μs |

The approximately 2.4% difference fell within `benchmark-ips` measurement
error in that run. Reproduce it with:

```console
bundle exec appraisal rails_8_0 ruby benchmark/non_nested_transaction.rb
```

## Development

```console
bundle install
bundle exec rake
bundle exec appraisal rails_7_1 rspec
bundle exec appraisal rails_7_2 rspec
bundle exec appraisal rails_8_0 rspec
bundle exec rake build
```

## License

Rollwire is available under the [MIT License](LICENSE.txt).
