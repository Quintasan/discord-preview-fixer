# frozen_string_literal: true

require_relative 'test_helper'

class InstagramTest < Minitest::Test
  def setup
    @link = URI.parse('https://www.instagram.com/reel/DRdnbpqkih8/?utm_source=ig_web_copy_link&igsh=NTc4MTIwNjQ2YQ==')
  end

  def test_link
    expected = 'https://eeinstagram.com/reel/DRdnbpqkih8/?utm_source=ig_web_copy_link&igsh=NTc4MTIwNjQ2YQ=='

    assert_equal expected, Instagram.fix_link(@link)
  end

  def test_without_www
    link = URI.parse('https://instagram.com/reel/abc/')

    assert_equal 'https://eeinstagram.com/reel/abc/', Instagram.fix_link(link)
  end

  def test_returns_nil_for_other_host
    assert_nil Instagram.fix_link(URI.parse('https://example.com/reel/abc/'))
  end
end
