# frozen_string_literal: true

require_relative 'test_helper'
require 'pruner'

class PrunerTest < Minitest::Test
  def setup
    Message.dataset.destroy
  end

  def test_forgets_records_past_the_cutoff
    stale_record(original_message_id: 1, fixed_message_id: 2, channel_id: 5_000)

    assert_equal 1, Pruner.run(older_than: days_ago(30))

    assert_nil Message.first(original_message_id: 1)
  end

  def test_keeps_records_inside_the_window
    stale_record(original_message_id: 1, fixed_message_id: 2, channel_id: 5_000)
    Message.record(original_message_id: 3, fixed_message_id: 4, channel_id: 5_000)

    assert_equal 1, Pruner.run(older_than: days_ago(30))

    refute_nil Message.first(original_message_id: 3)
  end

  def test_forgets_legacy_records_without_a_channel
    stale_record(original_message_id: 1, fixed_message_id: 2, channel_id: nil)

    assert_equal 1, Pruner.run(older_than: days_ago(30))

    assert_nil Message.first(original_message_id: 1)
  end

  def test_forgetting_the_same_window_twice_is_harmless
    stale_record(original_message_id: 1, fixed_message_id: 2, channel_id: 5_000)

    assert_equal 1, Pruner.run(older_than: days_ago(30))
    assert_equal 0, Pruner.run(older_than: days_ago(30))
  end

  def test_returns_zero_when_nothing_is_stale
    assert_equal 0, Pruner.run(older_than: days_ago(30))
  end

  private

  def stale_record(**attributes)
    Message.record(**attributes)
    Message.where(original_message_id: attributes[:original_message_id]).update(created_at: days_ago(40))
  end

  def days_ago(count)
    Time.now - (count * 86_400)
  end
end
