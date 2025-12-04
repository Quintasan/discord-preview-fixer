# frozen_string_literal: true

require_relative 'service'

class Reddit < Service
  HOST_REGEX = /(www.|old.)?reddit.com/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri.host = 'rxddit.com'
    uri.to_s
  end
end
