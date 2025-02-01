require 'pixiv'

class TestPixiv < Minitest::Test
  Event = Struct.new(:message)

  def setup
    @with_locale = Event.new(message: "https://www.pixiv.net/en/artworks/126308933")
    @without_locale = Event.new(message: "https://www.pixiv.net/artworks/126308933")
    @without_www = Event.new(message: "https://pixiv.net/en/artworks/126308933")
  end

  def test_link_with_locale
    expected = "https://www.phixiv.net/en/artworks/126308933"
    assert_equal expected, Pixiv.fix_link(@with_locale)
  end

  def test_link_without_locale
    expected = "https://www.phixiv.net/artworks/126308933"
    assert_equal expected, Pixiv.fix_link(@without_locale)
  end

  def test_without_www
    expected = "https://phixiv.net/en/artworks/126308933"
    assert_equal expected, Pixiv.fix_link(@without_www)
  end
end
