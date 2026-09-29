# frozen_string_literal: true

require_relative 'test_helper'

class AmiAmiTest < Minitest::Test
  def setup
    @figure_link = URI.parse('https://www.amiami.com/eng/detail/?gcode=FIGURE-181922')
  end

  def test_figure
    expected = 'https://figurki.harvestasha.org/eng/detail/?gcode=FIGURE-181922'

    assert_equal expected, AmiAmi.fix_link(@figure_link)
  end

  def test_without_www
    link = URI.parse('https://amiami.com/eng/detail/?gcode=FIGURE-1')

    assert_equal 'https://figurki.harvestasha.org/eng/detail/?gcode=FIGURE-1', AmiAmi.fix_link(link)
  end

  def test_returns_nil_for_other_host
    assert_nil AmiAmi.fix_link(URI.parse('https://example.com/eng/detail/'))
  end
end
