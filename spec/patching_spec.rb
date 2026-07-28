# frozen_string_literal: true

RSpec.describe "patch installation" do
  let(:log_output) { StringIO.new }

  before do
    Rollwire.configuration.logger = Logger.new(log_output)
  end

  it "disables detection and warns when patching fails" do
    allow(Rollwire::Patcher).to receive(:install!).and_raise(
      Rollwire::PatchingError,
      "unsupported"
    )

    expect(Rollwire.install!).to be(false)
    expect(Rollwire.enabled?).to be(false)
    expect(log_output.string).to include("unsupported")
  end

  it "raises a patching failure in strict mode" do
    Rollwire.configuration.strict_patching = true
    allow(Rollwire::Patcher).to receive(:install!).and_raise(
      Rollwire::PatchingError,
      "unsupported"
    )

    expect { Rollwire.install! }.to raise_error(Rollwire::PatchingError)
  end
end
