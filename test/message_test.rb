# frozen_string_literal: true

require_relative 'test_helper'

class MessageTest < Minitest::Test
  def setup
    Message.dataset.destroy
  end

  def test_create_message
    msg = Message.create(original_message_id: 111, fixed_message_id: 222)

    assert_equal 111, msg.original_message_id
    assert_equal 222, msg.fixed_message_id
  end

  def test_fetch_message
    Message.create(original_message_id: 111, fixed_message_id: 222)
    fetched = Message.first(original_message_id: 111)

    refute_nil fetched
    assert_equal 222, fetched.fixed_message_id
  end

  def test_delete_message
    Message.create(original_message_id: 111, fixed_message_id: 222)
    fetched = Message.first(original_message_id: 111)

    fetched.destroy

    assert_nil Message.first(original_message_id: 111)
  end

  def test_unique_message_constraint
    Message.create(original_message_id: 555, fixed_message_id: 666)
    assert_raises(Sequel::UniqueConstraintViolation) do
      Message.create(original_message_id: 555, fixed_message_id: 666)
    end
  end

  def test_presence_constraint
    assert_raises(Sequel::NotNullConstraintViolation) do
      Message.create(original_message_id: nil, fixed_message_id: nil)
    end
  end

  def test_sets_created_at_on_create
    msg = Message.create(original_message_id: 111, fixed_message_id: 222)

    refute_nil msg.created_at
  end

  def test_create_sets_created_at_when_omitted
    msg = Message.create(original_message_id: 111, fixed_message_id: 222, created_at: nil)

    refute_nil msg.created_at
  end

  def test_record_sets_created_at_and_channel
    Message.record(original_message_id: 1, fixed_message_id: 2, channel_id: 3)
    record = Message.first(original_message_id: 1)

    refute_nil record.created_at
    assert_equal 3, record.channel_id
  end

  def test_record_ignores_a_duplicate_insert
    Message.record(original_message_id: 1, fixed_message_id: 2, channel_id: 3)
    Message.record(original_message_id: 1, fixed_message_id: 99, channel_id: 4)

    record = Message.first(original_message_id: 1)

    assert_equal 2, record.fixed_message_id
    assert_equal 3, record.channel_id
  end

  def test_prune_removes_only_records_older_than_the_cutoff
    Message.create(original_message_id: 1, fixed_message_id: 2, created_at: days_ago(40))
    Message.create(original_message_id: 3, fixed_message_id: 4, created_at: days_ago(10))

    assert_equal 1, Message.prune(older_than: days_ago(30))
    assert_nil Message.first(original_message_id: 1)
    refute_nil Message.first(original_message_id: 3)
  end

  def test_prune_returns_zero_when_nothing_is_stale
    Message.create(original_message_id: 1, fixed_message_id: 2, created_at: days_ago(1))

    assert_equal 0, Message.prune(older_than: days_ago(30))
  end

  private

  def days_ago(count)
    Time.now - (count * 86_400)
  end
end
