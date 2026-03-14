# frozen_string_literal: true

require_relative 'service'

class Instagram < Service
  HOST_REGEX = /\A(www\.)?instagram\.com\z/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri = uri.dup
    uri.host = 'eeinstagram.com'
    uri.to_s
  end
end
