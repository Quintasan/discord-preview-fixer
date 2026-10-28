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

  def test_wraps_only_the_spoilered_link
    message = '|| https://twitter.com/a/status/1 || and https://twitter.com/b/status/2'

    assert_equal ['|| https://vxtwitter.com/a/status/1 ||', 'https://vxtwitter.com/b/status/2'],
                 LinkFixer.fix(message)
  end

  def test_wraps_links_inside_multiline_spoilers
    message = "||\nhttps://twitter.com/a/status/1\n||"

    assert_equal ['|| https://vxtwitter.com/a/status/1 ||'], LinkFixer.fix(message)
  end

  def test_spoils_a_link_that_also_appears_outside_a_spoiler
    message = 'https://twitter.com/a/status/1 ||https://twitter.com/a/status/1||'

    assert_equal ['|| https://vxtwitter.com/a/status/1 ||'], LinkFixer.fix(message)
  end

  def test_ignores_an_unmatched_spoiler_marker
    message = '|| https://twitter.com/a/status/1'

    assert_equal ['https://vxtwitter.com/a/status/1'], LinkFixer.fix(message)
  end

  def test_skips_links_inside_inline_code
    assert_empty LinkFixer.fix('`https://twitter.com/a/status/1`')
  end

  def test_skips_links_inside_multi_backtick_code
    assert_empty LinkFixer.fix('``https://twitter.com/a/status/1``')
  end

  def test_skips_links_inside_fenced_code
    assert_empty LinkFixer.fix("```\nhttps://twitter.com/a/status/1\n```")
  end

  def test_fixes_links_outside_code
    message = '`https://twitter.com/code/1` https://twitter.com/real/1'

    assert_equal ['https://vxtwitter.com/real/1'], LinkFixer.fix(message)
  end

  def test_continues_after_an_unmatched_code_marker
    message = '`unclosed https://twitter.com/a/status/1'

    assert_equal ['https://vxtwitter.com/a/status/1'], LinkFixer.fix(message)
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

  def test_ignores_malformed_uri_matched_by_regex
    assert_empty LinkFixer.fix('see http://#[ here')
  end

  def test_deduplicates_links_that_rewrite_to_the_same_fixed_url
    message = 'https://twitter.com/a/status/1 and https://x.com/a/status/1 and https://twitter.com/a/status/1'

    assert_equal ['https://vxtwitter.com/a/status/1'], LinkFixer.fix(message)
  end
end
