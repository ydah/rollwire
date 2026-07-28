# frozen_string_literal: true

RSpec.describe Rollwire::Report do
  def report(mode:)
    described_class.new(
      inner_location: "app/services/create_user.rb:24",
      mode: mode,
      outer_location: "app/services/import_users.rb:61",
      writes: 2
    )
  end

  it "describes writes as not rolled back in log and notify modes" do
    expect(report(mode: :log).to_s).to include("2 writes executed inside this block will not be rolled back")
    expect(report(mode: :notify).to_s).to include("2 writes executed inside this block will not be rolled back")
  end

  it "explains the changed database outcome in raise mode" do
    expect(report(mode: :raise).to_s).to include(
      "would not have been rolled back (this raise rolled back the outer transaction instead)"
    )
  end
end
