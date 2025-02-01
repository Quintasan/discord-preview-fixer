# frozen_string_literal: true

require_relative 'test_helper'

class AmiAmiTest < Minitest::Test
  def setup
    @figure_link = Event.new(message: 'https://www.amiami.com/eng/detail/?gcode=FIGURE-181922')
  end

  def test_figure
    expected = 'https://figurki.harvestasha.org/eng/detail/?gcode=FIGURE-181922'

    assert_equal expected, AmiAmi.fix_link(@figure_link)
  end
end
