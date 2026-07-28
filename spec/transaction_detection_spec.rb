# frozen_string_literal: true

RSpec.describe "ignored nested rollback detection" do
  include_context "with captured Rollwire reports"

  it "detects a rollback with a write in a joined nested transaction" do
    User.transaction do
      User.create!(name: "Kotori")
      User.transaction do
        User.create!(name: "Nemu")
        raise ActiveRecord::Rollback
      end
    end

    expect(User.order(:id).pluck(:name)).to eq(%w[Kotori Nemu])
    expect(reports.one?).to be(true)
    expect(reports.first).to have_attributes(writes: 1)
    expect(reports.first.inner_location).to include("spec/transaction_detection_spec.rb")
    expect(reports.first.outer_location).to include("spec/transaction_detection_spec.rb")
  end

  it "forwards transaction block arguments on Active Record versions that provide them" do
    yielded_transaction = nil
    User.transaction do
      User.transaction do |transaction|
        yielded_transaction = transaction
        raise ActiveRecord::Rollback
      end
    end

    if ActiveRecord.version >= Gem::Version.new("7.2")
      expect(yielded_transaction).not_to be_nil
    else
      expect(yielded_transaction).to be_nil
    end
  end

  it "does not report a joined rollback without writes" do
    User.transaction do
      User.transaction { raise ActiveRecord::Rollback }
    end

    expect(reports).to be_empty
  end

  it "detects subclasses of ActiveRecord::Rollback" do
    rollback_class = Class.new(ActiveRecord::Rollback)
    User.transaction do
      User.transaction do
        User.create!(name: "Nemu")
        raise rollback_class
      end
    end

    expect(reports.size).to eq(1)
  end

  it "does not report or retain writes from requires_new transactions" do
    User.transaction do
      User.transaction(requires_new: true) do
        User.create!(name: "Nemu")
        raise ActiveRecord::Rollback
      end
    end

    expect(User.count).to be_zero
    expect(reports).to be_empty
  end

  it "does not report an outermost rollback" do
    User.transaction do
      User.create!(name: "Kotori")
      raise ActiveRecord::Rollback
    end

    expect(User.count).to be_zero
    expect(reports).to be_empty
  end

  it "does not report a direct child of a non-joinable parent" do
    connection = ActiveRecord::Base.connection
    connection.transaction(joinable: false) do
      User.transaction do
        User.create!(name: "Nemu")
        raise ActiveRecord::Rollback
      end
    end

    expect(User.count).to be_zero
    expect(reports).to be_empty
  end

  it "reports two application levels inside a transactional-fixture parent" do
    connection = ActiveRecord::Base.connection
    connection.transaction(joinable: false) do
      User.transaction do
        User.transaction do
          User.create!(name: "Nemu")
          raise ActiveRecord::Rollback
        end
      end
    end

    expect(User.pluck(:name)).to eq(["Nemu"])
    expect(reports.size).to eq(1)
  end

  it "reports only the innermost rollback in a three-level nesting" do
    User.transaction do
      User.transaction do
        User.transaction do
          User.create!(name: "Nemu")
          raise ActiveRecord::Rollback
        end
      end
    end

    expect(reports.size).to eq(1)
    expect(Rollwire::WriteCounter.frame_count).to be_zero
  end

  it "preserves TransactionIsolationError and balances the frame stack" do
    expect do
      User.transaction do
        User.transaction(isolation: :serializable) { User.count }
      end
    end.to raise_error(ActiveRecord::TransactionIsolationError)

    expect(reports).to be_empty
    expect(Rollwire::WriteCounter.frame_count).to be_zero
  end
end
