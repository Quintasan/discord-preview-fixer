# frozen_string_literal: true

module TikTok
  REGEX = %r{https?://(?<subdomain>www.|vm.)?(?<tld>tiktok.com)(?<rest>/\S*)}i

  def self.fix_link(event)
    message = event.message.to_s
    old_link = message.match(REGEX).to_s
    old_link.gsub('tiktok', 'vxtiktok')
  end
end
