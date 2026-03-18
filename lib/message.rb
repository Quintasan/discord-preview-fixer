# frozen_string_literal: true

require 'sequel'

DB = Sequel.sqlite(ENV.fetch('DB_PATH', 'messages.db'))
DB.run('PRAGMA journal_mode=WAL')
DB.run('PRAGMA busy_timeout=5000')

DB.create_table?(:messages) do
  primary_key :id
  Bignum :original_message_id, null: false
  Bignum :fixed_message_id, null: false
  index :original_message_id, unique: true
end

class Message < Sequel::Model(:messages)
  plugin :validation_helpers

  def validate
    super
    validates_presence %i[original_message_id fixed_message_id]
    validates_unique :original_message_id
  end
end