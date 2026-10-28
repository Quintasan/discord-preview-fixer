# frozen_string_literal: true

require_relative 'test_helper'

class MessageSchemaTest < Minitest::Test
  def test_installs_the_current_schema
    db = Sequel.sqlite

    MessageSchema.install(db)

    columns = db.schema(:messages).map(&:first)

    assert_includes columns, :created_at
    assert_includes columns, :channel_id
    assert db.indexes(:messages).key?(:messages_fixed_message_id_index)
  end

  def test_installs_the_created_at_index
    db = Sequel.sqlite

    MessageSchema.install(db)

    assert db.indexes(:messages).key?(:messages_created_at_index)
  end

  def test_backfills_created_at_on_a_legacy_database
    db = legacy_database
    db[:messages].insert(original_message_id: 1, fixed_message_id: 2)

    MessageSchema.install(db)

    refute_nil db[:messages].first[:created_at]
  end

  def test_adds_channel_id_to_a_legacy_database
    db = legacy_database

    MessageSchema.install(db)

    assert_includes db.schema(:messages).map(&:first), :channel_id
  end

  def test_adds_the_fixed_message_id_index_to_a_legacy_database
    db = legacy_database

    MessageSchema.install(db)

    assert db.indexes(:messages).key?(:messages_fixed_message_id_index)
  end

  def test_adds_the_created_at_index_to_a_legacy_database
    db = legacy_database

    MessageSchema.install(db)

    assert db.indexes(:messages).key?(:messages_created_at_index)
  end

  def test_install_is_idempotent
    db = Sequel.sqlite

    MessageSchema.install(db)
    MessageSchema.install(db)

    assert_empty db[:messages]
    assert db.indexes(:messages).key?(:messages_created_at_index)
  end

  private

  # The table shape from before created_at, channel_id, and the
  # fixed_message_id and created_at indexes existed.
  def legacy_database
    db = Sequel.sqlite
    db.create_table(:messages) do
      primary_key :id
      Integer :original_message_id, null: false
      Integer :fixed_message_id, null: false
      index :original_message_id, unique: true
    end
    db
  end
end
