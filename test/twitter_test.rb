# frozen_string_literal: true

require_relative 'test_helper'

class TwitterTest < Minitest::Test
  def setup
    @twitter_link = URI.parse('https://twitter.com/cutesexyrobutts/status/1674537984614432768')
    @xcom_link = URI.parse('https://x.com/cutesexyrobutts/status/1674537984614432768')
    @expected = 'https://vxtwitter.com/cutesexyrobutts/status/1674537984614432768'
  end

  def test_twitter_link
    assert_equal @expected, Twitter.fix_link(@twitter_link)
  end

  def test_xcom_link
    assert_equal @expected, Twitter.fix_link(@xcom_link)
  end
end
