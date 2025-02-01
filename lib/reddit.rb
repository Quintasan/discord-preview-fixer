# frozen_string_literal: true

module Reddit
  REGEX = %r{https?://(?<subdomain>www.|old.)?(?<tld>reddit.com)(?<rest>/\S*)}i

  def self.fix_link(event)
    message = event.message.to_s
    old_link = message.match(REGEX).to_s
    old_link.gsub('reddit', 'rxddit')
  end
end
