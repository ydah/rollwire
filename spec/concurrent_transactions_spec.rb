# frozen_string_literal: true

require "timeout"

RSpec.describe "concurrent Active Record transactions" do
  include_context "with captured Rollwire reports"

  it "isolates reports from overlapping transactions on separate connection pools" do
    synchronization = build_synchronization
    workers = start_workers(synchronization)

    wait_for(synchronization[:outer_started], 2)
    release(synchronization[:run_nested], 2)
    wait_for(synchronization[:nested_finished], 2)
    release(synchronization[:finish_outer], 2)
    Timeout.timeout(10) { workers.each(&:value) }

    expect(reports.map(&:writes)).to contain_exactly(1, 1)
    expect(User.pluck(:name)).to eq(["Kotori"])
    expect(SecondaryUser.pluck(:name)).to eq(["Nemu"])
    expect(Rollwire::WriteCounter.frame_count).to be_zero
  ensure
    release(synchronization[:finish_outer], 2) if synchronization
    workers&.each { |worker| worker.kill if worker.alive? }
    workers&.each(&:join)
  end

  private

  def build_synchronization
    {
      finish_outer: Queue.new,
      nested_finished: Queue.new,
      outer_started: Queue.new,
      run_nested: Queue.new
    }
  end

  def start_workers(synchronization)
    ActiveRecord::Base.connection_pool.release_connection
    SecondaryRecord.connection_pool.release_connection

    [
      start_worker(User, "Kotori", synchronization),
      start_worker(SecondaryUser, "Nemu", synchronization)
    ]
  end

  def start_worker(model, name, synchronization)
    Thread.new do
      model.connection_pool.with_connection do
        model.transaction do
          synchronization[:outer_started] << true
          synchronization[:run_nested].pop

          model.transaction do
            model.create!(name: name)
            raise ActiveRecord::Rollback
          end

          synchronization[:nested_finished] << true
          synchronization[:finish_outer].pop
        end
      end
    end
  end

  def wait_for(queue, count)
    Timeout.timeout(10) { count.times { queue.pop } }
  end

  def release(queue, count)
    count.times { queue << true }
  end
end
