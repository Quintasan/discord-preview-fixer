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
    assert_raises(Sequel::ValidationFailed) do
      Message.create(original_message_id: 555, fixed_message_id: 666)
    end
  end

  def test_presence_validation
    assert_raises(Sequel::ValidationFailed) do
      Message.create(original_message_id: nil, fixed_message_id: nil)
    end
  end
end
