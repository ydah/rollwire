# frozen_string_literal: true

RSpec.shared_context "with captured Rollwire reports" do
  let(:reports) { [] }
  let(:log_output) { StringIO.new }
  let(:logger) { Logger.new(log_output) }

  before do
    Rollwire.configure do |config|
      config.logger = logger
      config.mode = :notify
    end

    @rollwire_subscription = ActiveSupport::Notifications.subscribe(
      Rollwire::Report::EVENT_NAME
    ) do |*, payload|
      reports << payload.fetch(:report)
    end
  end

  after do
    ActiveSupport::Notifications.unsubscribe(@rollwire_subscription)
  end

  def run_ignored_rollback
    User.transaction do
      User.create!(name: "Kotori")
      User.transaction do
        User.create!(name: "Nemu")
        raise ActiveRecord::Rollback
      end
    end
  end
end
