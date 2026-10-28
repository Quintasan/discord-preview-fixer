# frozen_string_literal: true

require 'sequel'
require_relative 'message_schema'

DB = Sequel.sqlite(ENV.fetch('DB_PATH', 'messages.db'))
DB.run('PRAGMA journal_mode=WAL')
DB.run('PRAGMA busy_timeout=5000')
MessageSchema.install(DB)

class Message < Sequel::Model(:messages)
  # Records the fixed reply for an original message. created_at is set
  # explicitly because databases created before that column existed have no
  # column default, and the upsert keeps a raced duplicate from raising.
  def self.record(original_message_id:, fixed_message_id:, channel_id: nil)
    dataset.insert_conflict(target: :original_message_id).insert(
      original_message_id: original_message_id,
      fixed_message_id: fixed_message_id,
      channel_id: channel_id,
      created_at: Time.now
    )
  end

  # Forgets records past the retention window. The fixed reply is deliberately
  # left in place: retention bounds what the bot remembers, and edits to messages
  # older than the window are ignored, so no reply ever has to be resolved.
  def self.prune(older_than:)
    where { created_at < older_than }.delete
  end

  # Databases created before created_at existed have no column default.
  def before_create
    self.created_at ||= Time.now
    super
  end
end
