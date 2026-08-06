# frozen_string_literal: true

require_relative 'test_helper'

class LinkFixerTest < Minitest::Test
  def test_single_supported_link
    message = 'check out https://twitter.com/cutesexyrobutts/status/1674537984614432768'

    assert_equal ['https://vxtwitter.com/cutesexyrobutts/status/1674537984614432768'],
                 LinkFixer.fix(message)
  end

  def test_trailing_punctuation_is_stripped
    message = 'https://twitter.com/cutesexyrobutts/status/1674537984614432768!'

    assert_equal ['https://vxtwitter.com/cutesexyrobutts/status/1674537984614432768'],
                 LinkFixer.fix(message)
  end

  def test_url_in_parentheses_with_trailing_punctuation
    message = '(see https://twitter.com/cutesexyrobutts/status/1674537984614432768).'

    assert_equal ['https://vxtwitter.com/cutesexyrobutts/status/1674537984614432768'],
                 LinkFixer.fix(message)
  end

  def test_skips_unsupported_url_and_fixes_later_supported_one
    message = 'https://example.com/page and https://x.com/user/status/123'

    assert_equal ['https://vxtwitter.com/user/status/123'], LinkFixer.fix(message)
  end

  def test_fixes_multiple_supported_links
    message = 'https://twitter.com/a/status/1 https://pixiv.net/en/artworks/2'

    assert_equal ['https://vxtwitter.com/a/status/1', 'https://phixiv.net/en/artworks/2'],
                 LinkFixer.fix(message)
  end

  def test_returns_empty_for_message_without_links
    assert_empty LinkFixer.fix('no links here')
  end

  def test_returns_empty_for_unsupported_links
    assert_empty LinkFixer.fix('https://example.com/page')
  end

  def test_wraps_links_in_spoilers_when_message_has_spoiler_markers
    message = '|| https://twitter.com/a/status/1 ||'

    assert_equal ['|| https://vxtwitter.com/a/status/1 ||'], LinkFixer.fix(message)
  end

  def test_does_not_wrap_links_in_spoilers_without_markers
    message = 'https://twitter.com/a/status/1'

    assert_equal ['https://vxtwitter.com/a/status/1'], LinkFixer.fix(message)
  end

  def test_matches_case_insensitive_hosts
    message = 'https://TWITTER.com/a/status/1'

    assert_equal ['https://vxtwitter.com/a/status/1'], LinkFixer.fix(message)
  end

  def test_returns_empty_for_nil
    assert_empty LinkFixer.fix(nil)
  end
end
