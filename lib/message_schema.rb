# frozen_string_literal: true

require 'sequel'

# Owns the messages table layout, including the one-time migration of databases
# created before created_at, channel_id, or the fixed_message_id index existed.
class MessageSchema
  FIXED_MESSAGE_ID_INDEX = :messages_fixed_message_id_index

  class << self
    def install(db)
      create_messages_table(db)
      backfill_created_at(db)
      add_channel_id(db)
      add_fixed_message_id_index(db)
    end

    private

    def create_messages_table(db)
      db.create_table?(:messages) do
        primary_key :id
        Integer :original_message_id, null: false
        Integer :fixed_message_id, null: false
        Integer :channel_id
        DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
        index :original_message_id, unique: true
        index :fixed_message_id
      end
    end

    def backfill_created_at(db)
      return if columns(db).include?(:created_at)

      db.alter_table(:messages) { add_column :created_at, DateTime }
      db[:messages].where(created_at: nil).update(created_at: Sequel::CURRENT_TIMESTAMP)
    end

    def add_channel_id(db)
      return if columns(db).include?(:channel_id)

      db.alter_table(:messages) { add_column :channel_id, Integer }
    end

    def add_fixed_message_id_index(db)
      return if db.indexes(:messages).key?(FIXED_MESSAGE_ID_INDEX)

      db.add_index(:messages, :fixed_message_id)
    end

    def columns(db)
      db.schema(:messages).map(&:first)
    end
  end
end
