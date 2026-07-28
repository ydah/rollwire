# frozen_string_literal: true

RSpec.describe Rollwire::Configuration do
  subject(:configuration) { described_class.new }

  it "provides safe production defaults" do
    expect(configuration).to have_attributes(
      backtrace_lines: 10,
      capture_outer_location: true,
      count_writes: true,
      min_writes: 1,
      mode: :log,
      strict_patching: false
    )
  end

  it "uses raise mode for tests unless mode was explicitly configured" do
    configuration.apply_environment_default!(test: true)
    expect(configuration.mode).to eq(:raise)

    explicit_configuration = described_class.new
    explicit_configuration.mode = :notify
    explicit_configuration.apply_environment_default!(test: true)
    expect(explicit_configuration.mode).to eq(:notify)
  end

  it "rejects invalid settings" do
    expect { configuration.mode = :unknown }.to raise_error(Rollwire::ConfigurationError)
    expect { configuration.min_writes = -1 }.to raise_error(Rollwire::ConfigurationError)
    expect { configuration.backtrace_lines = 0 }.to raise_error(Rollwire::ConfigurationError)
    expect { configuration.count_writes = nil }.to raise_error(Rollwire::ConfigurationError)
    expect { configuration.ignore_if = "no" }.to raise_error(Rollwire::ConfigurationError)
  end
end
