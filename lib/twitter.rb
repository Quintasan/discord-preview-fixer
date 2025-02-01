# frozen_string_literal: true

module Twitter
  REGEX = %r{https?://(?<www>www.)?(?<domain>twitter.com|x.com)/(?<username>\S+)/status/(?<post_id>\d+)}i

  def self.fix_link(event)
    results = event.message.to_s.match(REGEX)
    old_link = results.to_s
    case results[:domain]
    when 'x.com'
      old_link.gsub('x.com', 'vxtwitter.com')
    when 'twitter.com'
      old_link.gsub('twitter.com', 'vxtwitter.com')
    end
  end
end
