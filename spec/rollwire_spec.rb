# frozen_string_literal: true

RSpec.describe Rollwire do
  it "has a version number" do
    expect(Rollwire::VERSION).not_to be nil
  end

  it "loads Active Record" do
    expect(ActiveRecord.version).to be >= Gem::Version.new("7.1")
  end
end
