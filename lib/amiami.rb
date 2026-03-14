# frozen_string_literal: true

require_relative 'service'

class AmiAmi < Service
  HOST_REGEX = /\A(www\.)?amiami\.com\z/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri.host = 'figurki.harvestasha.org'
    uri.to_s
  end
end
