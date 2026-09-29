# frozen_string_literal: true

require_relative 'test_helper'

class TiktokTest < Minitest::Test
  def setup
    @link = URI.parse('https://www.tiktok.com/@username/video/1234567890123456789')
    @short_link = URI.parse('https://vm.tiktok.com/ZMeXxxxxx/')
    @without_www = URI.parse('https://tiktok.com/@username/video/1234567890123456789')
  end

  def test_link
    expected = 'https://tnktok.com/@username/video/1234567890123456789'

    assert_equal expected, Tiktok.fix_link(@link)
  end

  def test_short_link
    expected = 'https://tnktok.com/ZMeXxxxxx/'

    assert_equal expected, Tiktok.fix_link(@short_link)
  end

  def test_without_www
    expected = 'https://tnktok.com/@username/video/1234567890123456789'

    assert_equal expected, Tiktok.fix_link(@without_www)
  end

  def test_vt_short_link
    link = URI.parse('https://vt.tiktok.com/ZMeXxxxxx/')

    assert_equal 'https://tnktok.com/ZMeXxxxxx/', Tiktok.fix_link(link)
  end

  def test_returns_nil_for_other_host
    assert_nil Tiktok.fix_link(URI.parse('https://example.com/@username/video/1'))
  end
end
