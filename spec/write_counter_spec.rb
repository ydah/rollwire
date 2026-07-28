# frozen_string_literal: true

RSpec.describe Rollwire::WriteCounter do
  let(:connection) { Object.new }

  after do
    described_class.reset!
  end

  it "counts writes from SQL text, including leading comments" do
    described_class.push_frame(connection)
    described_class.record(
      connection: connection,
      name: "User Update",
      sql: "/* application:rollwire */\n UPDATE users SET name = 'Nemu'"
    )

    expect(described_class.current_writes(connection)).to eq(1)
  end

  it "counts SELECT FOR UPDATE as a write-sensitive operation" do
    described_class.push_frame(connection)
    described_class.record(
      connection: connection,
      name: "User Load",
      sql: "SELECT * FROM users WHERE id = 1 FOR UPDATE"
    )

    expect(described_class.current_writes(connection)).to eq(1)
  end

  it "ignores schema, transaction, read, and other-connection events" do
    described_class.push_frame(connection)
    described_class.record(connection: connection, name: "SCHEMA", sql: "INSERT INTO users VALUES (1)")
    described_class.record(connection: connection, name: "User Load", sql: "SELECT * FROM users")
    described_class.record(connection: Object.new, name: "SQL", sql: "DELETE FROM users")

    expect(described_class.current_writes(connection)).to be_zero
  end

  it "increments every matching frame in a nested stack" do
    described_class.push_frame(connection)
    described_class.push_frame(connection)
    described_class.record(connection: connection, name: "SQL", sql: "INSERT INTO users DEFAULT VALUES")

    expect(described_class.current_writes(connection)).to eq(1)
    described_class.pop_frame(connection)
    expect(described_class.current_writes(connection)).to eq(1)
  end

  it "does not mix connections" do
    other_connection = Object.new
    described_class.push_frame(connection)
    described_class.push_frame(other_connection)
    described_class.record(connection: other_connection, name: "SQL", sql: "DELETE FROM users")

    expect(described_class.current_writes(connection)).to be_zero
    expect(described_class.current_writes(other_connection)).to eq(1)
  end

  it "isolates frames between threads" do
    ready = Queue.new
    release = Queue.new

    worker = Thread.new do
      described_class.push_frame(connection)
      described_class.record(connection: connection, name: "SQL", sql: "INSERT INTO users DEFAULT VALUES")
      ready << described_class.current_writes(connection)
      release.pop
    ensure
      described_class.reset!
    end

    expect(ready.pop).to eq(1)
    expect(described_class.current_writes(connection)).to be_zero
    release << true
    worker.join
  end
end
