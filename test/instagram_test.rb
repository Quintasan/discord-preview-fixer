require_relative 'test_helper'

class TestInstagram < Minitest::Test
  def setup
    @link = URI.parse('https://www.instagram.com/reel/DRdnbpqkih8/?utm_source=ig_web_copy_link&igsh=NTc4MTIwNjQ2YQ==')
  end

  def test_link
    expected = 'https://eeinstagram.com/reel/DRdnbpqkih8/?utm_source=ig_web_copy_link&igsh=NTc4MTIwNjQ2YQ=='

    assert_equal expected, Instagram.fix_link(@link)
  end
end
