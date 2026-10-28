# frozen_string_literal: true

require_relative 'test_helper'

# One table of every supported URL shape, instead of a test file per service.
class ServicesTest < Minitest::Test
  SERVICES = [Twitter, Pixiv, Reddit, AmiAmi, Instagram, Tiktok].freeze

  # service, source URL, rewritten URL
  REWRITES = [
    [Twitter, 'https://twitter.com/cutesexyrobutts/status/1674537984614432768',
     'https://vxtwitter.com/cutesexyrobutts/status/1674537984614432768'],
    [Twitter, 'https://x.com/cutesexyrobutts/status/1674537984614432768',
     'https://vxtwitter.com/cutesexyrobutts/status/1674537984614432768'],
    [Twitter, 'https://TWITTER.COM/user/status/1', 'https://vxtwitter.com/user/status/1'],
    [Twitter, 'https://mobile.twitter.com/user/status/1', 'https://vxtwitter.com/user/status/1'],
    [Pixiv, 'https://www.pixiv.net/en/artworks/126308933', 'https://phixiv.net/en/artworks/126308933'],
    [Pixiv, 'https://www.pixiv.net/artworks/126308933', 'https://phixiv.net/artworks/126308933'],
    [Pixiv, 'https://pixiv.net/en/artworks/126308933', 'https://phixiv.net/en/artworks/126308933'],
    [Pixiv, 'https://WWW.PIXIV.NET/en/artworks/1', 'https://phixiv.net/en/artworks/1'],
    [Reddit, 'https://www.reddit.com/r/onebag/comments/1ifcejr/35l_backpack_vs_carry_on_suitcase',
     'https://rxddit.com/r/onebag/comments/1ifcejr/35l_backpack_vs_carry_on_suitcase'],
    [Reddit, 'https://old.reddit.com/r/onebag', 'https://rxddit.com/r/onebag'],
    [Reddit, 'https://new.reddit.com/r/onebag', 'https://rxddit.com/r/onebag'],
    [Reddit, 'https://np.reddit.com/r/onebag', 'https://rxddit.com/r/onebag'],
    [Reddit, 'https://i.reddit.com/r/onebag', 'https://rxddit.com/r/onebag'],
    [Reddit, 'https://reddit.com/r/onebag', 'https://rxddit.com/r/onebag'],
    [AmiAmi, 'https://www.amiami.com/eng/detail/?gcode=FIGURE-181922',
     'https://figurki.harvestasha.org/eng/detail/?gcode=FIGURE-181922'],
    [AmiAmi, 'https://amiami.com/eng/detail/?gcode=FIGURE-1',
     'https://figurki.harvestasha.org/eng/detail/?gcode=FIGURE-1'],
    [Instagram, 'https://www.instagram.com/reel/DRdnbpqkih8/?utm_source=ig_web_copy_link&igsh=NTc4MTIwNjQ2YQ==',
     'https://eeinstagram.com/reel/DRdnbpqkih8/?utm_source=ig_web_copy_link&igsh=NTc4MTIwNjQ2YQ=='],
    [Instagram, 'https://instagram.com/reel/abc/', 'https://eeinstagram.com/reel/abc/'],
    [Instagram, 'https://m.instagram.com/reel/abc/', 'https://eeinstagram.com/reel/abc/'],
    [Instagram, 'https://instagr.am/p/abc/', 'https://eeinstagram.com/p/abc/'],
    [Tiktok, 'https://www.tiktok.com/@username/video/1234567890123456789',
     'https://tnktok.com/@username/video/1234567890123456789'],
    [Tiktok, 'https://vm.tiktok.com/ZMeXxxxxx/', 'https://tnktok.com/ZMeXxxxxx/'],
    [Tiktok, 'https://tiktok.com/@username/video/1234567890123456789',
     'https://tnktok.com/@username/video/1234567890123456789'],
    [Tiktok, 'https://vt.tiktok.com/ZMeXxxxxx/', 'https://tnktok.com/ZMeXxxxxx/']
  ].freeze

  def test_rewrites_supported_urls
    REWRITES.each do |service, source, expected|
      assert_equal expected, service.fix_link(URI.parse(source)), "rewriting #{source}"
    end
  end

  def test_ignores_unrelated_hosts
    SERVICES.each do |service|
      actual = service.fix_link(URI.parse('https://example.com/page'))

      assert_nil actual, "#{service.name} matched an unrelated host"
    end
  end

  def test_each_source_url_matches_only_its_service
    REWRITES.each do |service, source, _|
      matches = SERVICES.select { |candidate| candidate.fix_link(URI.parse(source)) }

      assert_equal [service], matches, "#{source} matched #{matches.map(&:name)}"
    end
  end

  def test_every_service_is_covered_by_the_rewrite_table
    assert_equal SERVICES.sort_by(&:name), Service.subclasses.select(&:name).sort_by(&:name)
  end
end
