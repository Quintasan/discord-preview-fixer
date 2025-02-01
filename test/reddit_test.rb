# frozen_string_literal: true

require_relative 'test_helper'

class RedditTest < Minitest::Test
  def setup
    @reddit_link = Event.new(message: 'https://www.reddit.com/r/onebag/comments/1ifcejr/35l_backpack_vs_carry_on_suitcase')
    @expected = 'https://www.rxddit.com/r/onebag/comments/1ifcejr/35l_backpack_vs_carry_on_suitcase'
  end

  def test_reddit_link
    assert_equal @expected, Reddit.fix_link(@reddit_link)
  end
end
