# frozen_string_literal: true

require_relative 'test_helper'

class TikTokTest < Minitest::Test
  def setup
    @tiktok_link = Event.new(message: 'https://vm.tiktok.com/ZNeoNf3yN/')
    @expected = 'https://vm.vxtiktok.com/ZNeoNf3yN/'
  end

  def test_tiktok_link
    assert_equal @expected, TikTok.fix_link(@tiktok_link)
  end
end
