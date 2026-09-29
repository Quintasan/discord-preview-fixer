# frozen_string_literal: true

require_relative 'test_helper'

class RedditTest < Minitest::Test
  def setup
    @reddit_link = URI.parse('https://www.reddit.com/r/onebag/comments/1ifcejr/35l_backpack_vs_carry_on_suitcase')
    @expected = 'https://rxddit.com/r/onebag/comments/1ifcejr/35l_backpack_vs_carry_on_suitcase'
  end

  def test_reddit_link
    assert_equal @expected, Reddit.fix_link(@reddit_link)
  end

  def test_old_reddit_link
    link = URI.parse('https://old.reddit.com/r/onebag')

    assert_equal 'https://rxddit.com/r/onebag', Reddit.fix_link(link)
  end

  def test_without_www
    link = URI.parse('https://reddit.com/r/onebag')

    assert_equal 'https://rxddit.com/r/onebag', Reddit.fix_link(link)
  end

  def test_returns_nil_for_other_host
    assert_nil Reddit.fix_link(URI.parse('https://example.com/r/onebag'))
  end
end
