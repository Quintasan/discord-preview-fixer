# frozen_string_literal: true

require_relative 'service'

class Pixiv < Service
  HOST_REGEX = /\A(www\.)?pixiv\.net\z/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri = uri.dup
    uri.host = 'phixiv.net'
    uri.to_s
  end
end
