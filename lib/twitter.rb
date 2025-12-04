# frozen_string_literal: true

require_relative 'service'

class Twitter < Service
  HOST_REGEX = /^(www.)?(twitter.com|x.com)$/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri.host = 'vxtwitter.com'
    uri.to_s
  end
end
