module Pixiv
  REGEX = %r{https?://(?<www>www.)?(?<domain>pixiv.net)/(?<lang>\S+/)?artworks/\d+}

  def self.fix_link(event)
    message = event.message.to_s
    old_link = message.match(REGEX).to_s
    old_link.gsub('pixiv', 'phixiv')
  end
end
