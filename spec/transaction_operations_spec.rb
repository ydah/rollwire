# frozen_string_literal: true

RSpec.describe "Rollwire operation modes and controls" do
  include_context "with captured Rollwire reports"

  it "does not push or pop frames while disabled" do
    allow(Rollwire::WriteCounter).to receive(:push_frame).and_call_original
    allow(Rollwire::WriteCounter).to receive(:pop_frame).and_call_original
    Rollwire.disable!

    run_ignored_rollback

    expect(Rollwire::WriteCounter).not_to have_received(:push_frame)
    expect(Rollwire::WriteCounter).not_to have_received(:pop_frame)
    expect(reports).to be_empty
  end

  it "preserves Rails behavior and does not pop if pushing a frame fails" do
    allow(Rollwire::WriteCounter).to receive(:push_frame).and_raise("counter failed")
    allow(Rollwire::WriteCounter).to receive(:pop_frame).and_call_original

    run_ignored_rollback

    expect(Rollwire::WriteCounter).not_to have_received(:pop_frame)
    expect(User.order(:id).pluck(:name)).to eq(%w[Kotori Nemu])
    expect(log_output.string).to include("internal error: RuntimeError: counter failed")
  end

  it "keeps both records in log mode" do
    Rollwire.configuration.mode = :log

    run_ignored_rollback

    expect(User.order(:id).pluck(:name)).to eq(%w[Kotori Nemu])
    expect(log_output.string).to include("will not be rolled back")
  end

  it "rolls back the outer transaction in raise mode" do
    Rollwire.configuration.mode = :raise

    expect { run_ignored_rollback }.to raise_error(Rollwire::IgnoredNestedRollback)

    expect(User.count).to be_zero
  end

  it "warns and preserves Rails behavior if the notifier fails" do
    Rollwire.configuration.mode = :log
    allow(Rollwire::Notifier).to receive(:call).and_raise("notifier failed")

    run_ignored_rollback

    expect(User.order(:id).pluck(:name)).to eq(%w[Kotori Nemu])
    expect(log_output.string).to include("internal error: RuntimeError: notifier failed")
  end

  it "supports suppression and ignore predicates" do
    Rollwire.suppress { run_ignored_rollback }
    expect(reports).to be_empty

    User.delete_all
    Rollwire.configuration.ignore_if = ->(report) { report.inner_location.include?("spec/") }
    run_ignored_rollback
    expect(reports).to be_empty
  end

  it "restores suppression after an exception" do
    expect do
      Rollwire.suppress { raise "application failure" }
    end.to raise_error("application failure")

    run_ignored_rollback
    expect(reports.size).to eq(1)
  end

  it "can disable outer-location capture" do
    Rollwire.configuration.capture_outer_location = false

    run_ignored_rollback

    expect(reports.first.outer_location).to be_nil
  end

  it "can detect without write counting" do
    Rollwire.configuration.count_writes = false

    User.transaction do
      User.transaction { raise ActiveRecord::Rollback }
    end

    expect(reports.size).to eq(1)
    expect(reports.first.writes).to be_zero
  end

  it "honors the minimum write count" do
    Rollwire.configuration.min_writes = 2
    run_ignored_rollback
    expect(reports).to be_empty

    User.delete_all
    User.transaction do
      User.transaction do
        User.create!(name: "Kotori")
        User.create!(name: "Nemu")
        raise ActiveRecord::Rollback
      end
    end
    expect(reports.size).to eq(1)
    expect(reports.first.writes).to eq(2)
  end

  it "counts update_columns and raw execute writes" do
    user = User.create!(name: "Kotori")
    User.transaction do
      User.transaction do
        user.update_columns(name: "Nemu")
        ActiveRecord::Base.connection.execute(
          "INSERT INTO users (name, lock_version) VALUES ('Rikka', 0)"
        )
        raise ActiveRecord::Rollback
      end
    end

    expect(reports.first.writes).to eq(2)
  end

  it "does not mix writes from two database connections" do
    User.transaction do
      User.transaction do
        User.create!(name: "Kotori")

        SecondaryUser.transaction do
          SecondaryUser.transaction do
            SecondaryUser.create!(name: "Nemu")
            raise ActiveRecord::Rollback
          end
        end

        raise ActiveRecord::Rollback
      end
    end

    expect(reports.map(&:writes)).to eq([1, 1])
    expect(User.pluck(:name)).to eq(["Kotori"])
    expect(SecondaryUser.pluck(:name)).to eq(["Nemu"])
  end
end
