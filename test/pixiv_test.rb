# frozen_string_literal: true

require_relative 'test_helper'

class PixivTest < Minitest::Test
  def setup
    @with_locale = URI.parse('https://www.pixiv.net/en/artworks/126308933')
    @without_locale = URI.parse('https://www.pixiv.net/artworks/126308933')
    @without_www = URI.parse('https://pixiv.net/en/artworks/126308933')
  end

  def test_link_with_locale
    expected = 'https://phixiv.net/en/artworks/126308933'

    assert_equal expected, Pixiv.fix_link(@with_locale)
  end

  def test_link_without_locale
    expected = 'https://phixiv.net/artworks/126308933'

    assert_equal expected, Pixiv.fix_link(@without_locale)
  end

  def test_without_www
    expected = 'https://phixiv.net/en/artworks/126308933'

    assert_equal expected, Pixiv.fix_link(@without_www)
  end

  def test_uppercase_host
    link = URI.parse('https://WWW.PIXIV.NET/en/artworks/1')

    assert_equal 'https://phixiv.net/en/artworks/1', Pixiv.fix_link(link)
  end

  def test_returns_nil_for_other_host
    assert_nil Pixiv.fix_link(URI.parse('https://example.com/en/artworks/1'))
  end
end
