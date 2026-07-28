# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - Unreleased

- Detect ignored `ActiveRecord::Rollback` exceptions in joined nested transactions.
- Count writes per connection and execution context to reduce false positives.
- Report inner and outer transaction locations.
- Support log, notification, and test-only raise modes.
- Support Active Record 7.1, 7.2, and 8.0 on Ruby 3.1 and newer.
