# frozen_string_literal: true

require_relative 'service'

class Twitter < Service
  HOST_REGEX = /\A(www\.|mobile\.)?(twitter\.com|x\.com)\z/i
  REPLACEMENT_HOST = 'vxtwitter.com'

  # Only posts expand. Profiles, media tabs, hashtags, searches, and every
  # other path are left alone: vxtwitter has nothing useful to preview for
  # them, and a rewritten profile link is just noise.
  POST_PATH = %r{\A/(?:[^/]+|i/web)/status(?:es)?/\d+}

  def self.fix_link(uri)
    # @type var path: String
    path = uri.path
    return unless POST_PATH.match?(path)

    super
  end
end
