# frozen_string_literal: true

require 'sequel'
require_relative 'message_schema'

DB = Sequel.sqlite(ENV.fetch('DB_PATH', 'messages.db'))
DB.run('PRAGMA journal_mode=WAL')
DB.run('PRAGMA busy_timeout=5000')
MessageSchema.install(DB)

class Message < Sequel::Model(:messages)
  plugin :validation_helpers

  # Drops records whose original message deletion was never observed, e.g.
  # because the bot was offline when it happened.
  def self.prune(older_than:)
    where { created_at < older_than }.delete
  end

  def validate
    super
    validates_presence %i[original_message_id fixed_message_id]
    validates_unique :original_message_id
  end
end
