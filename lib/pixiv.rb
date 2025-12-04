# frozen_string_literal: true

require_relative 'service'

class Pixiv < Service
  HOST_REGEX = /(www.)?pixiv.net/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri.host = 'phixiv.net'
    uri.to_s
  end
end
