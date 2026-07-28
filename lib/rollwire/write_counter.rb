# frozen_string_literal: true

require "active_support/notifications"

module Rollwire
  module WriteCounter
    Frame = Struct.new(:connection, :writes, keyword_init: true)

    IGNORED_EVENT_NAMES = %w[SCHEMA TRANSACTION].freeze
    MUTATION_SQL = /\A(?:INSERT|UPDATE|DELETE)\b/i
    LOCKING_READ_SQL = /\ASELECT\b.*\bFOR\s+UPDATE\b/im
    LEADING_COMMENTS = %r{\A(?:\s|/\*.*?\*/|--[^\n]*(?:\n|\z))*}m

    module_function

    def start!
      return if @subscription

      @subscription_mutex ||= Mutex.new
      @subscription_mutex.synchronize do
        return if @subscription

        @subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*arguments|
          record(arguments.last)
        rescue StandardError => e
          Rollwire.warn_internal_error(e)
        end
      end
    end

    def push_frame(connection)
      current_frames! << Frame.new(connection: connection, writes: 0)
    end

    def pop_frame(connection)
      frames = current_frames
      return unless frames

      index = frames.rindex { |frame| frame.connection.equal?(connection) }
      frame = frames.delete_at(index) if index
      ExecutionState.delete(:write_counter_frames) if frames.empty?
      frame
    end

    def current_writes(connection)
      frame = current_frames&.reverse_each&.find { |candidate| candidate.connection.equal?(connection) }
      frame&.writes || 0
    end

    def record(payload)
      return unless Rollwire.configuration.count_writes
      return unless current_frames&.any?
      return unless write_event?(payload)

      current_frames.each do |frame|
        frame.writes += 1 if frame.connection.equal?(payload[:connection])
      end
    end

    def reset!
      ExecutionState.delete(:write_counter_frames)
    end

    def frame_count
      current_frames&.length || 0
    end

    def current_frames
      ExecutionState.read(:write_counter_frames)
    end
    private_class_method :current_frames

    def current_frames!
      current_frames || ExecutionState.write(:write_counter_frames, [])
    end
    private_class_method :current_frames!

    def write_event?(payload)
      return false unless payload.is_a?(Hash)
      return false if IGNORED_EVENT_NAMES.include?(payload[:name])
      return false unless payload[:connection]

      sql = payload[:sql].to_s.sub(LEADING_COMMENTS, "")
      MUTATION_SQL.match?(sql) || LOCKING_READ_SQL.match?(sql)
    end
    private_class_method :write_event?
  end
end
