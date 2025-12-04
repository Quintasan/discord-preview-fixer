require_relative 'service'

class Instagram < Service
  HOST_REGEX = /(www.)?instagram.com/i

  def self.fix_link(uri)
    return unless uri.host.match?(HOST_REGEX)

    uri.host = 'eeinstagram.com'
    uri.to_s
  end
end
