# frozen_string_literal: true

require_relative 'service'

class TikTok < Service
  HOST_REGEX = /^(www.|vm.)?tiktok.com$/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri.host = 'vxtiktok.com'
    uri.to_s
  end
end
